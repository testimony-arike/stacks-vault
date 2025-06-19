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