;; Mock Fungible Token Contract for Testing
;; Implements SIP-010 trait

(impl-trait 'STM6S3AESTK9NAYE3Z7RS00T11ER8JJCDNTKG711.sip-010-trait.sip-010-trait)

;; Define the token
(define-fungible-token non-whitelisted-ft)

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u1))

;; Define data variables
(define-data-var token-name (string-ascii 32) "Non-Whitelisted-Ft")
(define-data-var token-symbol (string-ascii 10) "NWF")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var token-decimals uint u6)

;; SIP-010 Functions

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq tx-sender from) (is-eq contract-caller from)) err-not-token-owner)
    (ft-transfer? non-whitelisted-ft amount from to)
  )
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance non-whitelisted-ft who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply non-whitelisted-ft))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Mint function for testing
(define-public (mint (amount uint) (to principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ft-mint? non-whitelisted-ft amount to)
  )
)

;; Initialize with some tokens for testing
(mint u10000000 contract-owner)
(mint u1000000 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(mint u1000000 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
(mint u1000000 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC)