;; title: marketplace-fulfill
;; version:
;; summary:
;; description:

;; traits
;;
(use-trait ft-trait  'STM6S3AESTK9NAYE3Z7RS00T11ER8JJCDNTKG711.sip-010-trait.sip-010-trait)


;; token definitions
;;

;; constants
;;
(define-constant ERR_UNKNOWN_LISTING (err u6000))
(define-constant ERR_LISTING_EXPIRED (err u6002))
(define-constant ERR_FT_ASSET_MISMATCH (err u6003))
(define-constant ERR_PAYMENT_ASSET_MISMATCH (err u6004))
(define-constant ERR_MAKER_TAKER_EQUAL (err u6005))
(define-constant ERR_UNINTENDED_TAKER (err u6006))



;; data vars
;;

;; data maps
;;

;; public functions
;;
(define-public (fulfil-listing-ft-stx (listing-id uint) (ft-asset-contract <ft-trait>) (amt uint))
  (let (
    ;; Verify the given listing ID exists
    (listing (unwrap! (contract-call? .marketplace get-listing-map listing-id) ERR_UNKNOWN_LISTING))
    ;; Set the ft's taker to the purchaser (caller of the_function)
    
  )
    ;; Validate that the purchase can be fulfilled
    (try! (assert-can-fulfil-ft (contract-of ft-asset-contract) none listing))
    (try! (contract-call? .marketplace fulfil-listing-ft-stx listing-id ft-asset-contract amt))
    
    (ok true)
  )
)

(define-public (fulfil-ft-listing-ft
  (listing-id uint)
  (ft-asset-contract <ft-trait>)
  (payment-asset-contract <ft-trait>)
  (amt uint)
)
  (let (
    ;; Verify the given listing ID exists
    (listing (unwrap! (contract-call? .marketplace get-listing-map listing-id) ERR_UNKNOWN_LISTING))
    ;; Set the ft's taker to the purchaser (caller of the_function)
  )
    ;; Validate that the purchase can be fulfilled
    (try! (assert-can-fulfil-ft
      (contract-of ft-asset-contract)
      (some (contract-of payment-asset-contract))
      listing
    ))
    (try! (contract-call? .marketplace fulfil-ft-listing-ft listing-id ft-asset-contract payment-asset-contract amt))
    (ok true)
  )
)

;; read only functions
;;


;; Private function to validate that a purchase can be fulfilled
(define-private (assert-can-fulfil-ft
  (ft-asset-contract principal)
  (payment-asset-contract (optional principal))
  (listing {
    maker: principal,
    taker: (optional principal),
    amt: uint,
    ft-asset-contract: principal,
    expiry: uint,
    price: uint,
    payment-asset-contract: (optional principal)
  })
)
  (begin
    ;; Verify that the buyer is not the same as the FT creator
    (asserts! (not (is-eq (get maker listing) tx-sender)) ERR_MAKER_TAKER_EQUAL)
    ;; Verify the buyer has been set in the listing metadata as its `taker`
    (asserts!
      (match (get taker listing) intended-taker (is-eq intended-taker tx-sender) true)
      ERR_UNINTENDED_TAKER
    )
    
    ;; Verify the listing for purchase is not expired
    (asserts! (< burn-block-height (get expiry listing)) ERR_LISTING_EXPIRED)
    ;; Verify the asset contract used to purchase the FT is the same as the one set on the FT
    (asserts! (is-eq (get ft-asset-contract listing) ft-asset-contract) ERR_FT_ASSET_MISMATCH)
    ;; Verify the payment contract used to purchase the FT is the same as the one set on the FT
    (asserts!
      (is-eq (get payment-asset-contract listing) payment-asset-contract)
      ERR_PAYMENT_ASSET_MISMATCH
    )
    (ok true)
  )
)



