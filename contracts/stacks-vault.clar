;; StacksVault Protocol - Advanced NFT Ecosystem
;; Title: StacksVault - Comprehensive NFT Infrastructure for Stacks Layer 2
;;
;; Summary: A next-generation NFT protocol enabling collateralized minting, fractional ownership,
;;          decentralized marketplace trading, and yield-generating staking mechanisms
;;
;; Description: StacksVault revolutionizes NFT utility on Stacks by combining traditional NFT
;;              functionality with DeFi primitives. Users can mint NFTs with collateral backing,
;;              fractionalize ownership for increased liquidity, trade on an integrated marketplace
;;              with automated fee distribution, and stake NFTs to earn consistent yields.
;;
;;              Key Features:
;;              - Collateral-backed NFT minting with configurable ratios
;;              - Fractional ownership system for enhanced liquidity
;;              - Integrated marketplace with protocol fee mechanisms
;;              - Yield-generating NFT staking with block-based rewards
;;              - Comprehensive access controls and safety validations

;; PROTOCOL CONSTANTS & ERROR HANDLING

(define-constant contract-owner tx-sender)

;; Access Control Errors
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))

;; Financial Operation Errors
(define-constant err-insufficient-balance (err u102))
(define-constant err-insufficient-collateral (err u106))

;; NFT Operation Errors
(define-constant err-invalid-token (err u103))
(define-constant err-listing-not-found (err u104))
(define-constant err-invalid-price (err u105))

;; Staking Operation Errors
(define-constant err-already-staked (err u107))
(define-constant err-not-staked (err u108))

;; Validation Errors
(define-constant err-invalid-percentage (err u109))
(define-constant err-invalid-uri (err u110))
(define-constant err-invalid-recipient (err u111))
(define-constant err-overflow (err u112))

;; PROTOCOL CONFIGURATION VARIABLES

(define-data-var min-collateral-ratio uint u150) ;; 150% minimum collateral ratio
(define-data-var protocol-fee uint u25) ;; 2.5% fee in basis points (250/10000)
(define-data-var total-staked uint u0) ;; Total number of staked NFTs
(define-data-var yield-rate uint u50) ;; 5% annual yield rate in basis points
(define-data-var total-supply uint u0) ;; Total NFTs minted

;; DATA STORAGE MAPS

;; Core NFT Registry
(define-map tokens
  { token-id: uint }
  {
    owner: principal,
    uri: (string-ascii 256),
    collateral: uint,
    is-staked: bool,
    stake-timestamp: uint,
    fractional-shares: uint,
  }
)

;; Marketplace Listings Registry
(define-map token-listings
  { token-id: uint }
  {
    price: uint,
    seller: principal,
    active: bool,
  }
)

;; Fractional Ownership Ledger
(define-map fractional-ownership
  {
    token-id: uint,
    owner: principal,
  }
  { shares: uint }
)

;; Staking Rewards Tracking
(define-map staking-rewards
  { token-id: uint }
  {
    accumulated-yield: uint,
    last-claim: uint,
  }
)

;; PRIVATE UTILITY FUNCTIONS

(define-private (validate-uri (uri (string-ascii 256)))
  ;; Validates URI format and length constraints
  (let ((uri-len (len uri)))
    (and
      (> uri-len u0)
      (<= uri-len u256)
    )
  )
)

(define-private (validate-recipient (recipient principal))
  ;; Ensures recipient is not the contract itself
  (not (is-eq recipient (as-contract tx-sender)))
)

(define-private (safe-add
    (a uint)
    (b uint)
  )
  ;; Performs safe addition with overflow protection
  (let ((sum (+ a b)))
    (asserts! (>= sum a) err-overflow)
    (ok sum)
  )
)

;; CORE NFT FUNCTIONALITY

(define-public (mint-nft
    (uri (string-ascii 256))
    (collateral uint)
  )
  ;; Mints a new NFT with collateral backing and metadata URI
  (let (
      (token-id (+ (var-get total-supply) u1))
      (collateral-requirement (/ (* (var-get min-collateral-ratio) collateral) u100))
    )
    (asserts! (validate-uri uri) err-invalid-uri)
    (asserts! (>= (stx-get-balance tx-sender) collateral-requirement)
      err-insufficient-collateral
    )
    (try! (stx-transfer? collateral-requirement tx-sender (as-contract tx-sender)))
    (map-set tokens { token-id: token-id } {
      owner: tx-sender,
      uri: uri,
      collateral: collateral,
      is-staked: false,
      stake-timestamp: u0,
      fractional-shares: u0,
    })
    (var-set total-supply token-id)
    (ok token-id)
  )
)

(define-public (transfer-nft
    (token-id uint)
    (recipient principal)
  )
  ;; Transfers NFT ownership to a new recipient
  (let ((token (unwrap! (get-token-info token-id) err-invalid-token)))
    (asserts! (validate-recipient recipient) err-invalid-recipient)
    (asserts! (is-eq tx-sender (get owner token)) err-not-token-owner)
    (asserts! (not (get is-staked token)) err-already-staked)
    (map-set tokens { token-id: token-id } (merge token { owner: recipient }))
    (ok true)
  )
)

;; DECENTRALIZED MARKETPLACE

(define-public (list-nft
    (token-id uint)
    (price uint)
  )
  ;; Lists an NFT for sale on the marketplace
  (let ((token (unwrap! (get-token-info token-id) err-invalid-token)))
    (asserts! (> price u0) err-invalid-price)
    (asserts! (is-eq tx-sender (get owner token)) err-not-token-owner)
    (asserts! (not (get is-staked token)) err-already-staked)
    (map-set token-listings { token-id: token-id } {
      price: price,
      seller: tx-sender,
      active: true,
    })
    (ok true)
  )
)

(define-public (purchase-nft (token-id uint))
  ;; Purchases an NFT from the marketplace with automatic fee distribution
  (let (
      (listing (unwrap! (get-listing token-id) err-listing-not-found))
      (price (get price listing))
      (seller (get seller listing))
      (fee (/ (* price (var-get protocol-fee)) u1000))
    )
    (asserts! (get active listing) err-listing-not-found)
    ;; Execute payment transfers
    (try! (stx-transfer? price tx-sender seller))
    (try! (stx-transfer? fee tx-sender (as-contract tx-sender)))
    ;; Transfer NFT ownership
    (try! (transfer-nft token-id tx-sender))
    ;; Deactivate listing
    (map-set token-listings { token-id: token-id } {
      price: u0,
      seller: seller,
      active: false,
    })
    (ok true)
  )
)

;; FRACTIONAL OWNERSHIP SYSTEM

(define-public (transfer-shares
    (token-id uint)
    (recipient principal)
    (share-amount uint)
  )
  ;; Transfers fractional ownership shares between users
  (let (
      (sender-shares (unwrap! (get-fractional-shares token-id tx-sender)
        err-insufficient-balance
      ))
      (current-recipient-shares (default-to { shares: u0 } (get-fractional-shares token-id recipient)))
      (recipient-new-shares (unwrap! (safe-add (get shares current-recipient-shares) share-amount)
        err-overflow
      ))
    )
    (asserts! (validate-recipient recipient) err-invalid-recipient)
    (asserts! (>= (get shares sender-shares) share-amount)
      err-insufficient-balance
    )
    ;; Update sender's share balance
    (map-set fractional-ownership {
      token-id: token-id,
      owner: tx-sender,
    } { shares: (- (get shares sender-shares) share-amount) }
    )
    ;; Update recipient's share balance
    (map-set fractional-ownership {
      token-id: token-id,
      owner: recipient,
    } { shares: recipient-new-shares }
    )
    (ok true)
  )
)