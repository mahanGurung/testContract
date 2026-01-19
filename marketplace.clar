;; ;; A ft marketplace that allows users to list ft for sale. They can specify the following:
;; ;; - The ft token to sell.
;; ;; - Listing expiry in block height.
;; ;; - The payment asset, either STX or a SIP010 fungible token.
;; ;; - The ft price in said payment asset.
;; ;; - An optional intended taker. If set, only that principal will be able to fulfil the listing.
;; ;;
;; ;; Source: https://github.com/clarity-lang/book/tree/main/projects/tiny-market


;; (use-trait ft-trait 'STM6S3AESTK9NAYE3Z7RS00T11ER8JJCDNTKG711.sip-010-trait.sip-010-trait)
;; (use-trait call-owner .token-trait.token-trait)



;; ;; listing errors
;; (define-constant ERR_EXPIRY_IN_PAST (err u1000))
;; (define-constant ERR_PRICE_ZERO (err u1001))
;; (define-constant ERR_AMOUNT_ZERO (err u1002))
;; (define-constant ERR_NOT_ADMIN (err u1003))


;; ;; cancelling and fulfiling errors
;; (define-constant ERR_UNKNOWN_LISTING (err u2000))
;; (define-constant ERR_UNAUTHORISED (err u2001))
;; (define-constant ERR_LISTING_EXPIRED (err u2002))
;; (define-constant ERR_FT_ASSET_MISMATCH (err u2003))
;; (define-constant ERR_PAYMENT_ASSET_MISMATCH (err u2004))
;; (define-constant ERR_MAKER_TAKER_EQUAL (err u2005))
;; (define-constant ERR_UNINTENDED_TAKER (err u2006))
;; (define-constant ERR_ASSET_CONTRACT_NOT_WHITELISTED (err u2007))
;; (define-constant ERR_PAYMENT_CONTRACT_NOT_WHITELISTED (err u2008))
;; (define-constant ERR_AMOUNT_IS_BIGGER (err u2009))


;; ;; emergency and fee errors
;; (define-constant ERR_CONTRACT_PAUSED (err u3000))
;; (define-constant ERR_INSUFFICIENT_BALANCE (err u3001))

;; (define-constant ERR_FT_AND_CALL_NOT_EQUAL (err u3002))
;; (define-constant ERR_NOT_ASSET_OWNER (err u3003))
;; (define-constant ERR_GETTING_ASSET_OWNER (err u3004))




;; (define-constant admin-role 0x00)
;; (define-constant fulfill-role 0x01)

;; ;; Emergency stop and transaction fee data variables
;; (define-data-var emergency-stop bool false)
;; ;; Changed: Single percentage-based transaction fee (5% = 500 basis points)
;; (define-data-var transaction-fee-bps uint u500) ;; Default 5% = 500 basis points
;; (define-constant BPS-DENOM u10000) ;; denominator for basis points

;; ;; Define a map data structure for the asset listings-ft
;; (define-map listings-ft
;;   uint
;;   {
;;     maker: principal,
;;     taker: (optional principal),
;;     amt: uint,
;;     ft-asset-contract: principal,
;;     expiry: uint,
;;     price: uint,
;;     payment-asset-contract: (optional principal),
    
;;   }
;; )

;; ;; Used for unique IDs for each listing
;; (define-data-var listing-ft-nonce uint u0)


;; (define-data-var contract-owner principal tx-sender)

;; ;; Function to calculate percentage-based fee
;; (define-private (calculate-transaction-fee (payment-amount uint))
;;   (/ (* payment-amount (var-get transaction-fee-bps)) BPS-DENOM)
;; )

;; ;; admin function: update contract owner
;; (define-public (set-contract-owner (new-owner principal))
;;   (if (is-eq tx-sender (var-get contract-owner))
;;       (begin (var-set contract-owner new-owner) (ok true))
;;       ERR_UNAUTHORISED
;;   )
;; )


;; ;; This marketplace requires any contracts used for assets or payments to be whitelisted
;; ;; by the contract owner of this (marketplace) contract.
;; (define-map whitelisted-asset-contracts principal bool)
;; ;; (map-set whitelisted-asset-contracts .mock-token true) ;;test
;; ;; (map-set whitelisted-asset-contracts .non-whitelisted-ft true) ;;test



;; (define-map active-protocol-contracts (buff 1) principal)
;; (map-set active-protocol-contracts 0x00 .marketplace-admin)
;; (map-set active-protocol-contracts 0x01 .marketplace-fulfill)

;; (define-map active-protocol-roles principal (buff 1))
;; (map-set active-protocol-roles .marketplace-admin admin-role)
;; (map-set active-protocol-roles .marketplace-fulfill fulfill-role)

;; ;; Emergency stop modifier - checks if contract is paused
;; (define-private (assert-not-paused)
;;   (begin
;;     (asserts! (not (var-get emergency-stop)) ERR_CONTRACT_PAUSED)
;;     (ok true)
;;   )
;; )

;; (define-read-only (get-contract-owner)
;;   (begin 
;;     (asserts! (is-eq (var-get contract-owner) contract-caller) ERR_NOT_ADMIN)
;;     (ok true)
;;   )
;; )

;; ;; Read-only functions
;; (define-read-only (get-listing-ft-nonce) 
;;   (ok (var-get listing-ft-nonce))
;; )


;; (define-read-only (get-listing-map (listing-id uint))
;;   (map-get? listings-ft listing-id)
;; )

;; (define-read-only (get-emergency-stop)
;;   (var-get emergency-stop)
;; )

;; ;; Single function to get transaction fee percentage
;; (define-read-only (get-transaction-fee-bps)
;;   (var-get transaction-fee-bps)
;; )

;; ;; Function to calculate fee for a given payment amount
;; (define-read-only (calculate-fee-for-amount (payment-amount uint))
;;   (calculate-transaction-fee payment-amount)
;; )

;; ;; Function that checks if the given contract has been whitelisted.
;; (define-read-only (is-whitelisted (asset-contract principal))
;;   (default-to false (map-get? whitelisted-asset-contracts asset-contract))
;; )

;; (define-read-only (is-protocol-caller (contract-flag (buff 1)) (contract principal))
;; 	(begin
;; 		;; Check that contract-caller is an protocol contract
;; 		(asserts! (is-eq (some contract) (map-get? active-protocol-contracts contract-flag)) ERR_UNAUTHORISED)
;; 		;; Check that flag matches the contract-caller
;; 		(asserts! (is-eq (some contract-flag) (map-get? active-protocol-roles contract)) ERR_UNAUTHORISED)
;; 		(ok true)
;; 	)
;; )

;; ;; Admin functions for emergency stop and fees
;; (define-public (set-emergency-stop (paused bool))
;;   (begin
;;     (asserts! (is-eq (var-get contract-owner) tx-sender) ERR_UNAUTHORISED)
;;     (var-set emergency-stop paused)
;;     (print {
;;       topic: "emergency-stop-updated",
;;       paused: paused,
;;       caller: tx-sender
;;     })
;;     (ok true)
;;   )
;; )

;; ;; Changed: Single function to set transaction fee percentage
;; (define-public (set-transaction-fee-bps (fee-bps uint))
;;   (begin
;;     (asserts! (is-eq (var-get contract-owner) tx-sender) ERR_UNAUTHORISED)
;;     (var-set transaction-fee-bps fee-bps)
;;     (print {
;;       topic: "transaction-fee-bps-updated",
;;       new-fee-bps: fee-bps,
;;       caller: tx-sender
;;     })
;;     (ok true)
;;   )
;; )

;; ;; Only the contract owner of this (marketplace) contract can whitelist an asset contract.
;; (define-public (set-whitelisted (asset-contract principal) (whitelisted bool))
;;   (begin
;;     (try! (assert-not-paused))
;;     (asserts! (is-eq (var-get contract-owner) tx-sender) ERR_UNAUTHORISED)
;;     (map-set whitelisted-asset-contracts asset-contract whitelisted)
;;     (print {
;;             whitelisted: asset-contract,
;;             isWhitelisted: whitelisted
;;           })
;;     (ok true)
;;   )
;; )

;; ;; Internal function to transfer fungible tokens from a sender to a given recipient.
;; (define-private (transfer-ft
;;   (token-contract <ft-trait>)
;;   (amount uint)
;;   (sender principal)
;;   (recipient principal)
;; )
;;   (contract-call? token-contract transfer amount sender recipient none)
;; )



;; ;; Public function to list an asset along with its contract
;; (define-public (list-asset-ft
;;   (ft-asset-contract <ft-trait>)
;;   (owner-asset-contract <call-owner>)
;;   (ft-asset {
;;     taker: (optional principal),
;;     amt: uint,
;;     expiry: uint,
;;     price: uint,
;;     payment-asset-contract: (optional principal)
;;   })
;; )
  
;;   (begin  
;;       ;; Check if contract is paused
;;       (try! (assert-not-paused))
;;       (asserts! (is-eq (contract-of ft-asset-contract) (contract-of owner-asset-contract)) ERR_FT_AND_CALL_NOT_EQUAL)
;;       (let ((listing-id (var-get listing-ft-nonce))
;;             (asset-owner (unwrap! (contract-call? owner-asset-contract get-owner) ERR_GETTING_ASSET_OWNER))
;;       )
          
;;         (asserts! (is-eq asset-owner tx-sender) ERR_NOT_ASSET_OWNER)
;;         ;; Verify that the contract of this asset is whitelisted
;;         (asserts! (is-whitelisted (contract-of ft-asset-contract)) ERR_ASSET_CONTRACT_NOT_WHITELISTED)
;;         ;; Verify that the asset is not expired
;;         ;; (asserts! (> (get expiry ft-asset) burn-block-height) ERR_EXPIRY_IN_PAST)
;;         ;; Verify that the asset price is greater than zero
;;         (asserts! (> (get price ft-asset) u0) ERR_PRICE_ZERO)
;;         ;; Verify that the asset amt is greater than zero
;;         (asserts! (> (get amt ft-asset) u0) ERR_AMOUNT_ZERO)

;;         ;; Verify that the contract of the payment is whitelisted
;;         (asserts! (match (get payment-asset-contract ft-asset)
;;           payment-asset
;;           (is-whitelisted payment-asset)
;;           true
;;         ) ERR_PAYMENT_CONTRACT_NOT_WHITELISTED)
        
;;         ;; Transfer the FT ownership to this contract's principal
;;         (try! (transfer-ft
;;           ft-asset-contract
;;           (get amt ft-asset)
;;           tx-sender
;;           (as-contract tx-sender)
;;         ))
;;         ;; List the FT in the listings map
;;         (map-set listings-ft listing-id (merge
;;           { maker: tx-sender, ft-asset-contract: (contract-of ft-asset-contract) }
;;           ft-asset
;;         ))
;;         ;; Increment the nonce to use for the next unique listing ID
;;         (var-set listing-ft-nonce (+ listing-id u1))

;;         (print {
;;             topic: "listing-creation",
;;             listing-id: listing-id,
;;             amount: (get amt ft-asset),
;;             price: (get price ft-asset),
;;             expiry: (get expiry ft-asset),
;;             maker: tx-sender,
;;             taker: (get taker ft-asset),
;;             asset-contract: ft-asset-contract,
;;             payment-asset-contract: (get payment-asset-contract ft-asset)
;;           })

;;         (ok true)
;;       )
  
;;   )
;; )

;; (define-public (cancel-listing-ft (listing-id uint) (ft-asset-contract <ft-trait>))
;;   (let (
;;     (listing (unwrap! (map-get? listings-ft listing-id) ERR_UNKNOWN_LISTING))
;;     (maker (get maker listing))
;;   )
;;     ;; Verify that the caller of the function is the creator of the FT to be cancelled
;;     (asserts! (is-eq maker tx-sender) ERR_UNAUTHORISED)
;;     ;; Verify that the asset contract to use is the same one that the FT uses
;;     (asserts! (is-eq
;;       (get ft-asset-contract listing)
;;       (contract-of ft-asset-contract)
;;     ) ERR_FT_ASSET_MISMATCH)
;;     ;; Delete the listing
;;     (map-delete listings-ft listing-id)
;;     ;; Transfer the FT from this contract's principal back to the creator's principal
;;     (try! (as-contract (transfer-ft ft-asset-contract (get amt listing) tx-sender maker)))

;;     (print {
;;       listing-id: listing-id,
;;       topic: "Cancel listing",
;;       ft-asset-contract: ft-asset-contract
;;     })

;;     (ok true)

;;   )
;; )


;; ;; Public function to update a listing (only callable by the listing's maker)
;; (define-public (update-listing-ft 
;;     (listing-id uint)
;;     (ft-asset-contract <ft-trait>)
;;     (new-amt (optional uint)) 
;;     (new-price (optional uint)) 
;;     (new-expiry (optional uint))
;;   )
;;   (let (
;;     ;; Fetch the listing, or fail if not found
;;     (listing (unwrap! (map-get? listings-ft listing-id) ERR_UNKNOWN_LISTING))
;;     (current-amt (get amt listing))
;;   )
;;     ;; Check if contract is paused
;;     (try! (assert-not-paused))
;;     ;; Ensure only the maker can update their listing
;;     (asserts! (is-eq tx-sender (get maker listing)) ERR_UNAUTHORISED)

;;     ;; Verify that the asset contract matches
;;     (asserts! (is-eq
;;       (get ft-asset-contract listing)
;;       (contract-of ft-asset-contract)
;;     ) ERR_FT_ASSET_MISMATCH)
    
;;     (let (
;;       ;; Use new values if provided, otherwise keep old values
;;       (updated-amt (default-to current-amt new-amt))
;;       (updated-price (default-to (get price listing) new-price))
;;       (updated-expiry (default-to (get expiry listing) new-expiry))
;;     )
;;       ;; Validate that updated amount is not zero
;;       (asserts! (> updated-amt u0) ERR_AMOUNT_ZERO)
;;       ;; Validate that updated price is not zero
;;       (asserts! (> updated-price u0) ERR_PRICE_ZERO)
;;       ;; Handle amount changes - transfer tokens if needed
;;       (if (not (is-eq updated-amt current-amt))
;;         (if (> updated-amt current-amt)
;;           ;; If increasing amount, user needs to transfer more tokens to contract
;;           (try! (transfer-ft
;;             ft-asset-contract
;;             (- updated-amt current-amt)
;;             tx-sender
;;             (as-contract tx-sender)
;;           ))
;;           ;; If decreasing amount, transfer excess tokens back to user
;;           (try! (as-contract (transfer-ft
;;             ft-asset-contract
;;             (- current-amt updated-amt)
;;             tx-sender
;;             (get maker listing)
;;           )))
;;         )
;;         ;; No amount change, do nothing
;;         true
;;       )
      
;;       ;; Update the listing in the map
;;       (map-set listings-ft listing-id
;;         {
;;           maker: (get maker listing),
;;           taker: (get taker listing),
;;           amt: updated-amt,
;;           ft-asset-contract: (get ft-asset-contract listing),
;;           expiry: updated-expiry,
;;           price: updated-price,
;;           payment-asset-contract: (get payment-asset-contract listing)
;;         }
;;       )
      
;;       ;; Print update event
;;       (print {
;;         topic: "listing-updated",
;;         listing-id: listing-id,
;;         old-amt: current-amt,
;;         new-amt: updated-amt,
;;         new-price: updated-price,
;;         new-expiry: updated-expiry,
;;         maker: (get maker listing)
;;       })
      
;;       (ok true)
;;     )
;;   )
;; )


;; ;; Public function to purchase a listing using STX as payment
;; (define-public (fulfil-listing-ft-stx (listing-id uint) (ft-asset-contract <ft-trait>) (amt uint))
;;  (let (
;;   ;; Verify the given listing ID exists
;;   (listing (unwrap! (map-get? listings-ft listing-id) ERR_UNKNOWN_LISTING))
;;   ;; Set the ft's taker to the purchaser (caller of the function)
;;   (taker tx-sender)
;;   ;; Calculate remaining amount
;;   (remaining-amt (- (get amt listing) amt))
  
;;   ;; Calculate total payment (price per unit * amount)
;;   (total-payment (* (get price listing) amt))
;;   ;; Changed: Calculate transaction fee as percentage of total payment
;;   (tx-fee (calculate-transaction-fee total-payment))
;;   ;; Calculate total cost (payment + fee)
;;   (total-cost (+ total-payment tx-fee))
;;  )
;;   ;; Check if contract is paused
;;   (try! (assert-not-paused))
;;   ;; Validate that the purchase can be fulfilled
;;   (try! (is-protocol-caller fulfill-role contract-caller))
;;   ;; Check if requested amount is valid
;;   (asserts! (>= (get amt listing) amt) ERR_AMOUNT_IS_BIGGER) ;;remove
;;   ;; Check that payment asset is STX (none means STX)
;;   (asserts! (is-none (get payment-asset-contract listing)) ERR_PAYMENT_ASSET_MISMATCH) ;;remove and put in fulfill contact is-none important
  
;;   ;; Transfer the ft to the purchaser (caller of the function)
;;   (try! (as-contract (transfer-ft ft-asset-contract amt tx-sender taker)))  ;;transfer
  
;;   ;; Transfer the STX payment from the purchaser to the creator of the ft
;;   (try! (stx-transfer? total-payment taker (get maker listing))) ;;transfer
  
;;   ;; Transfer the transaction fee to the contract owner 
;;   (if (not (is-eq taker (var-get contract-owner)))
;;     (try! (stx-transfer? tx-fee taker (var-get contract-owner)))
;;     true
;;   ) ;;transfer
  
;;   ;; Update or remove the listing based on remaining amount
;;   (if (is-eq remaining-amt u0)
;;     ;; If no amount remains, delete the listing
;;     (begin
;;       (map-delete listings-ft listing-id)
;;       (print {
;;         topic: "listing-fulfilled-stx",
;;         listing-id: listing-id,
;;         amt: amt,
;;         remaining-amt: remaining-amt,
;;         total-payment: total-payment,
;;         tx-fee: tx-fee,
;;         fee-percentage: (var-get transaction-fee-bps),
;;         buyer: taker,
;;         seller: (get maker listing)
;;       })
;;       (ok true)
;;     )
;;     ;; If amount remains, update the listing
;;     (begin
;;       (map-set listings-ft listing-id
;;         {
;;           maker: (get maker listing),
;;           taker: none,
;;           amt: remaining-amt,
;;           ft-asset-contract: (get ft-asset-contract listing),
;;           expiry: (get expiry listing),
;;           price: (get price listing),
;;           payment-asset-contract: (get payment-asset-contract listing)
;;         }
;;       )
;;       (print {
;;         topic: "listing-partially-fulfilled-stx",
;;         listing-id: listing-id,
;;         amt: amt,
;;         remaining-amt: remaining-amt,
;;         total-payment: total-payment,
;;         tx-fee: tx-fee,
;;         fee-percentage: (var-get transaction-fee-bps),
;;         buyer: taker,
;;         seller: (get maker listing)
;;       })
;;       (ok true)
;;     )
;;   )
;;  )
;; )

;; ;; Public function to purchase a listing using another fungible token as payment
;; (define-public (fulfil-ft-listing-ft
;;  (listing-id uint)
;;  (ft-asset-contract <ft-trait>)
;;  (payment-asset-contract <ft-trait>)
;;  (amt uint)
;; )
;;  (let (
;;   ;; Verify the given listing ID exists
;;   (listing (unwrap! (map-get? listings-ft listing-id) ERR_UNKNOWN_LISTING))
;;   ;; Set the ft's taker to the purchaser (caller of the function)
;;   (taker tx-sender)
;;   ;; Calculate remaining amount
;;   (remaining-amt (- (get amt listing) amt))
;;   ;; Calculate total payment (price per unit * amount)
;;   (total-payment (* (get price listing) amt))
;;   ;; Changed: Calculate transaction fee as percentage of total payment
;;   (tx-fee (calculate-transaction-fee total-payment))
;;  )
;;   ;; Check if contract is paused
;;   (try! (assert-not-paused))
;;   ;; Validate that the purchase can be fulfilled
;;   (try! (is-protocol-caller fulfill-role contract-caller))
;;   ;; Check if requested amount is valid
;;   (asserts! (>= (get amt listing) amt) ERR_AMOUNT_IS_BIGGER)
;;   ;; Check that payment asset contract matches
;;   (asserts! (is-eq 
;;     (some (contract-of payment-asset-contract)) 
;;     (get payment-asset-contract listing)
;;   ) ERR_PAYMENT_ASSET_MISMATCH) ;; remove this and put in fullfiill contract, some important
  
;;   ;; Transfer the ft to the purchaser (caller of the function)
;;   (try! (as-contract (transfer-ft ft-asset-contract amt tx-sender taker)))
  
;;   ;; Transfer the tokens as payment from the purchaser to the creator of the ft
;;   (try! (transfer-ft payment-asset-contract total-payment taker (get maker listing)))
  
;;   ;; Transfer the transaction fee to the contract owner (using same payment token)
;;   (if (not (is-eq taker (var-get contract-owner)))
;;     (try! (transfer-ft payment-asset-contract tx-fee taker (var-get contract-owner)))
;;     true
;;   ) ;;transfer
  
;;   ;; Update or remove the listing based on remaining amount
;;   (if (is-eq remaining-amt u0)
;;     ;; If no amount remains, delete the listing
;;     (begin
;;       (map-delete listings-ft listing-id)
;;       (print {
;;         topic: "listing-fulfilled-ft",
;;         listing-id: listing-id,
;;         amt: amt,
;;         remaining-amt: remaining-amt,
;;         total-payment: total-payment,
;;         tx-fee: tx-fee,
;;         fee-percentage: (var-get transaction-fee-bps),
;;         buyer: taker,
;;         seller: (get maker listing)
;;       })
;;       (ok true)
;;     )
;;     ;; If amount remains, update the listing
;;     (begin
;;       (map-set listings-ft listing-id
;;         {
;;           maker: (get maker listing),
;;           taker: none,
;;           amt: remaining-amt,
;;           ft-asset-contract: (get ft-asset-contract listing),
;;           expiry: (get expiry listing),
;;           price: (get price listing),
;;           payment-asset-contract: (get payment-asset-contract listing)
;;         }
;;       )
;;       (print {
;;         topic: "listing-partially-fulfilled-ft",
;;         listing-id: listing-id,
;;         amt: amt,
;;         remaining-amt: remaining-amt,
;;         total-payment: total-payment,
;;         tx-fee: tx-fee,
;;         fee-percentage: (var-get transaction-fee-bps),
;;         buyer: taker,
;;         seller: (get maker listing)
;;       })
;;       (ok true)
;;     )
;;   )
;;  )
;; )

;; (define-public (update-protocol-contract
;; 		(contract-type (buff 1))
;; 		(new-contract principal)
;; 	)
;; 	(begin
;; 		;; Check that caller is protocol contract
;; 		(try! (is-protocol-caller admin-role contract-caller))
;; 		;; Update the protocol contract
;; 		(map-set active-protocol-contracts contract-type new-contract)
;; 		;; Update the protocol role
;; 		(map-set active-protocol-roles new-contract contract-type)
;; 		(print {
;; 			topic: "update-protocol-contract",
;; 			contract-type: contract-type,
;; 			new-contract: new-contract,
;; 		})
;; 		(ok true)
;; 	)
;; )


;; ;; A ft marketplace that allows users to list ft for sale. They can specify the following:
;; ;; - The ft token to sell.
;; ;; - Listing expiry in block height.
;; ;; - The payment asset, either STX or a SIP010 fungible token.
;; ;; - The ft price in said payment asset.
;; ;; - An optional intended taker. If set, only that principal will be able to fulfil the listing.
;; ;;
;; ;; Source: https://github.com/clarity-lang/book/tree/main/projects/tiny-market


;; (use-trait ft-trait 'STM6S3AESTK9NAYE3Z7RS00T11ER8JJCDNTKG711.sip-010-trait.sip-010-trait)
;; (use-trait call-owner .token-trait.token-trait)



;; ;; listing errors
;; (define-constant ERR_EXPIRY_IN_PAST (err u1000))
;; (define-constant ERR_PRICE_ZERO (err u1001))
;; (define-constant ERR_AMOUNT_ZERO (err u1002))
;; (define-constant ERR_NOT_ADMIN (err u1003))


;; ;; cancelling and fulfiling errors
;; (define-constant ERR_UNKNOWN_LISTING (err u2000))
;; (define-constant ERR_UNAUTHORISED (err u2001))
;; (define-constant ERR_LISTING_EXPIRED (err u2002))
;; (define-constant ERR_FT_ASSET_MISMATCH (err u2003))
;; (define-constant ERR_PAYMENT_ASSET_MISMATCH (err u2004))
;; (define-constant ERR_MAKER_TAKER_EQUAL (err u2005))
;; (define-constant ERR_UNINTENDED_TAKER (err u2006))
;; (define-constant ERR_ASSET_CONTRACT_NOT_WHITELISTED (err u2007))
;; (define-constant ERR_PAYMENT_CONTRACT_NOT_WHITELISTED (err u2008))
;; (define-constant ERR_AMOUNT_IS_BIGGER (err u2009))


;; ;; emergency and fee errors
;; (define-constant ERR_CONTRACT_PAUSED (err u3000))
;; (define-constant ERR_INSUFFICIENT_BALANCE (err u3001))

;; (define-constant ERR_FT_AND_CALL_NOT_EQUAL (err u3002))
;; (define-constant ERR_NOT_ASSET_OWNER (err u3003))
;; (define-constant ERR_GETTING_ASSET_OWNER (err u3004))




;; (define-constant admin-role 0x00)
;; (define-constant fulfill-role 0x01)

;; ;; Emergency stop and transaction fee data variables
;; (define-data-var emergency-stop bool false)
;; ;; Changed: Single percentage-based transaction fee (5% = 500 basis points)
;; (define-data-var transaction-fee-bps uint u500) ;; Default 5% = 500 basis points
;; (define-constant BPS-DENOM u10000) ;; denominator for basis points

;; ;; Define a map data structure for the asset listings-ft
;; (define-map listings-ft
;;   {maker: principal, contractAddr: principal}
;;   {
;;     maker: principal,
;;     taker: (optional principal),
;;     amt: uint,
;;     ft-asset-contract: principal,
;;     expiry: uint,
;;     price: uint,
;;     payment-asset-contract: (optional principal)
;;   }
;; )

;; ;; Used for unique IDs for each listing
;; (define-data-var listing-ft-nonce uint u0)


;; (define-data-var contract-owner principal tx-sender)

;; ;; Function to calculate percentage-based fee
;; (define-private (calculate-transaction-fee (payment-amount uint))
;;   (/ (* payment-amount (var-get transaction-fee-bps)) BPS-DENOM)
;; )

;; ;; admin function: update contract owner
;; (define-public (set-contract-owner (new-owner principal))
;;   (if (is-eq tx-sender (var-get contract-owner))
;;       (begin (var-set contract-owner new-owner) (ok true))
;;       ERR_UNAUTHORISED
;;   )
;; )


;; ;; This marketplace requires any contracts used for assets or payments to be whitelisted
;; ;; by the contract owner of this (marketplace) contract.
;; (define-map whitelisted-asset-contracts principal bool)

;; (define-map whitelisted-payment-contracts principal bool)
;; ;; (map-set whitelisted-asset-contracts .mock-token true) ;;test
;; ;; (map-set whitelisted-asset-contracts .non-whitelisted-ft true) ;;test



;; (define-map active-protocol-contracts (buff 1) principal)
;; (map-set active-protocol-contracts 0x00 .marketplace-admin)
;; (map-set active-protocol-contracts 0x01 .marketplace-fulfill)

;; (define-map active-protocol-roles principal (buff 1))
;; (map-set active-protocol-roles .marketplace-admin admin-role)
;; (map-set active-protocol-roles .marketplace-fulfill fulfill-role)

;; ;; Emergency stop modifier - checks if contract is paused
;; (define-private (assert-not-paused)
;;   (begin
;;     (asserts! (not (var-get emergency-stop)) ERR_CONTRACT_PAUSED)
;;     (ok true)
;;   )
;; )

;; (define-read-only (get-contract-owner)
;;   (begin 
;;     (asserts! (is-eq (var-get contract-owner) contract-caller) ERR_NOT_ADMIN)
;;     (ok true)
;;   )
;; )

;; ;; Read-only functions
;; (define-read-only (get-listing-ft-nonce) 
;;   (ok (var-get listing-ft-nonce))
;; )


;; (define-read-only (get-listing-map (assetOwner principal) (ft-asset-contract principal))
;;   (map-get? listings-ft { maker: assetOwner, contractAddr: ft-asset-contract})
;; )

;; (define-read-only (get-emergency-stop)
;;   (var-get emergency-stop)
;; )

;; ;; Single function to get transaction fee percentage
;; (define-read-only (get-transaction-fee-bps)
;;   (var-get transaction-fee-bps)
;; )

;; ;; Function to calculate fee for a given payment amount
;; (define-read-only (calculate-fee-for-amount (payment-amount uint))
;;   (calculate-transaction-fee payment-amount)
;; )

;; ;; Function that checks if the given contract has been whitelisted.
;; (define-read-only (is-whitelisted (asset-contract principal))
;;   (default-to false (map-get? whitelisted-asset-contracts asset-contract))
;; )

;; (define-read-only (is-whitelisted-payment (payment-contract principal))
;;   (default-to false (map-get? whitelisted-payment-contracts payment-contract))
;; )

;; (define-read-only (is-protocol-caller (contract-flag (buff 1)) (contract principal))
;; 	(begin
;; 		;; Check that contract-caller is an protocol contract
;; 		(asserts! (is-eq (some contract) (map-get? active-protocol-contracts contract-flag)) ERR_UNAUTHORISED)
;; 		;; Check that flag matches the contract-caller
;; 		(asserts! (is-eq (some contract-flag) (map-get? active-protocol-roles contract)) ERR_UNAUTHORISED)
;; 		(ok true)
;; 	)
;; )

;; ;; Admin functions for emergency stop and fees
;; (define-public (set-emergency-stop (paused bool))
;;   (begin
;;     (asserts! (is-eq (var-get contract-owner) tx-sender) ERR_UNAUTHORISED)
;;     (var-set emergency-stop paused)
;;     (print {
;;       topic: "emergency-stop-updated",
;;       paused: paused,
;;       caller: tx-sender
;;     })
;;     (ok true)
;;   )
;; )

;; ;; Changed: Single function to set transaction fee percentage
;; (define-public (set-transaction-fee-bps (fee-bps uint))
;;   (begin
;;     (asserts! (is-eq (var-get contract-owner) tx-sender) ERR_UNAUTHORISED)
;;     (var-set transaction-fee-bps fee-bps)
;;     (print {
;;       topic: "transaction-fee-bps-updated",
;;       new-fee-bps: fee-bps,
;;       caller: tx-sender
;;     })
;;     (ok true)
;;   )
;; )

;; ;; Only the contract owner of this (marketplace) contract can whitelist an asset contract.
;; ;; test
;; (define-public (set-whitelisted (asset-contract principal) (whitelisted bool) (payment bool))
;;   (begin
;;     (try! (assert-not-paused))
;;     (asserts! (is-eq (var-get contract-owner) tx-sender) ERR_UNAUTHORISED)
;;     (if payment 
;;       (begin
;;         (map-set whitelisted-payment-contracts asset-contract whitelisted)
;;       (print {
;;               whitelisted-payment: asset-contract,
;;               isWhitelisted: whitelisted
;;             })
;;       (ok true))
;;       (begin 
;;       (map-set whitelisted-asset-contracts asset-contract whitelisted)
;;       (print {
;;               whitelisted-asset: asset-contract,
;;               isWhitelisted: whitelisted
;;             })
;;       (ok true))
;;       )
;;   )
;; )

;; ;; Internal function to transfer fungible tokens from a sender to a given recipient.
;; (define-private (transfer-ft
;;   (token-contract <ft-trait>)
;;   (amount uint)
;;   (sender principal)
;;   (recipient principal)
;; )
;;   (contract-call? token-contract transfer amount sender recipient none)
;; )



;; ;; Public function to list an asset along with its contract
;; (define-public (list-asset-ft
;;   (ft-asset-contract <ft-trait>)
;;   (owner-asset-contract <call-owner>)
;;   (ft-asset {
;;     taker: (optional principal),
;;     amt: uint,
;;     expiry: uint,
;;     price: uint,
;;     payment-asset-contract: (optional principal)
;;   })
;; )
  
;;   (begin  
;;       ;; Check if contract is paused
;;       (try! (assert-not-paused))
;;       (asserts! (is-eq (contract-of ft-asset-contract) (contract-of owner-asset-contract)) ERR_FT_AND_CALL_NOT_EQUAL)
;;       (let (
;;         ;; (listing-id (var-get listing-ft-nonce))
;;             (asset-owner (unwrap! (contract-call? owner-asset-contract get-owner) ERR_GETTING_ASSET_OWNER))
;;       )
          
;;         (asserts! (is-eq asset-owner contract-caller) ERR_NOT_ASSET_OWNER)
;;         ;; Verify that the contract of this asset is whitelisted
;;         (asserts! (is-whitelisted (contract-of ft-asset-contract)) ERR_ASSET_CONTRACT_NOT_WHITELISTED)
;;         ;; Verify that the asset is not expired
;;         ;; (asserts! (> (get expiry ft-asset) burn-block-height) ERR_EXPIRY_IN_PAST)
;;         ;; Verify that the asset price is greater than zero
;;         (asserts! (> (get price ft-asset) u0) ERR_PRICE_ZERO)
;;         ;; Verify that the asset amt is greater than zero
;;         (asserts! (> (get amt ft-asset) u0) ERR_AMOUNT_ZERO)

;;         ;; Verify that the contract of the payment is whitelisted
;;         (asserts! (match (get payment-asset-contract ft-asset)
;;           payment-asset
;;           (is-whitelisted-payment payment-asset)
;;           true
;;         ) ERR_PAYMENT_CONTRACT_NOT_WHITELISTED)
        
;;         ;; Transfer the FT ownership to this contract's principal
;;         (try! (transfer-ft
;;           ft-asset-contract
;;           (get amt ft-asset)
;;           tx-sender
;;           (as-contract tx-sender)
;;         ))
;;         ;; List the FT in the listings map
;;         (map-set listings-ft {maker:tx-sender, contractAddr: (contract-of ft-asset-contract)} (merge
;;           { maker: tx-sender, ft-asset-contract: (contract-of ft-asset-contract) }
;;           ft-asset
;;         ))
;;         ;; Increment the nonce to use for the next unique listing ID
;;         ;; (var-set listing-ft-nonce (+ listing-id u1))

;;         (print {
;;             topic: "listing-creation",
;;             ;; listing-id: listing-id,
;;             amount: (get amt ft-asset),
;;             price: (get price ft-asset),
;;             expiry: (get expiry ft-asset),
;;             maker: tx-sender,
;;             taker: (get taker ft-asset),
;;             asset-contract: ft-asset-contract,
;;             payment-asset-contract: (get payment-asset-contract ft-asset)
;;           })

;;         (ok true)
;;       )
  
;;   )
;; )

;; (define-public (cancel-listing-ft (ft-asset-contract <ft-trait>))
;;   (let (
;;     (listing (unwrap! (map-get? listings-ft { maker:contract-caller, contractAddr:(contract-of ft-asset-contract)} ) ERR_UNKNOWN_LISTING))
;;     (maker (get maker listing))
;;   )
;;     ;; Verify that the caller of the function is the creator of the FT to be cancelled
;;     (asserts! (is-eq maker tx-sender) ERR_UNAUTHORISED)
;;     ;; Verify that the asset contract to use is the same one that the FT uses
;;     (asserts! (is-eq
;;       (get ft-asset-contract listing)
;;       (contract-of ft-asset-contract)
;;     ) ERR_FT_ASSET_MISMATCH)
;;     ;; Delete the listing
;;     (map-delete listings-ft { maker:contract-caller, contractAddr:(contract-of ft-asset-contract)} )
;;     ;; Transfer the FT from this contract's principal back to the creator's principal
;;     (try! (as-contract (transfer-ft ft-asset-contract (get amt listing) tx-sender maker)))

;;     (print {
      
;;       topic: "Cancel listing",
;;       canceller: contract-caller,
;;       ft-asset-contract: ft-asset-contract
;;     })

;;     (ok true)

;;   )
;; )


;; ;; Public function to update a listing (only callable by the listing's maker)
;; (define-public (update-listing-ft 
    
;;     (ft-asset-contract <ft-trait>)
;;     (new-amt (optional uint)) 
;;     (new-price (optional uint)) 
;;     (new-expiry (optional uint))
;;   )
;;   (let (
;;     ;; Fetch the listing, or fail if not found
;;     (listing (unwrap! (map-get? listings-ft { maker: contract-caller, contractAddr: (contract-of ft-asset-contract)}) ERR_UNKNOWN_LISTING))
;;     (current-amt (get amt listing))
;;   )
;;     ;; Check if contract is paused
;;     (try! (assert-not-paused))
;;     ;; Ensure only the maker can update their listing
;;     (asserts! (is-eq tx-sender (get maker listing)) ERR_UNAUTHORISED)

;;     ;; Verify that the asset contract matches
;;     (asserts! (is-eq
;;       (get ft-asset-contract listing)
;;       (contract-of ft-asset-contract)
;;     ) ERR_FT_ASSET_MISMATCH)
    
;;     (let (
;;       ;; Use new values if provided, otherwise keep old values
;;       (updated-amt (default-to current-amt new-amt))
;;       (updated-price (default-to (get price listing) new-price))
;;       (updated-expiry (default-to (get expiry listing) new-expiry))
;;     )
;;       ;; Validate that updated amount is not zero
;;       (asserts! (> updated-amt u0) ERR_AMOUNT_ZERO)
;;       ;; Validate that updated price is not zero
;;       (asserts! (> updated-price u0) ERR_PRICE_ZERO)
;;       ;; Handle amount changes - transfer tokens if needed
;;       (if (not (is-eq updated-amt current-amt))
;;         (if (> updated-amt current-amt)
;;           ;; If increasing amount, user needs to transfer more tokens to contract
;;           (try! (transfer-ft
;;             ft-asset-contract
;;             (- updated-amt current-amt)
;;             tx-sender
;;             (as-contract tx-sender)
;;           ))
;;           ;; If decreasing amount, transfer excess tokens back to user
;;           (try! (as-contract (transfer-ft
;;             ft-asset-contract
;;             (- current-amt updated-amt)
;;             tx-sender
;;             (get maker listing)
;;           )))
;;         )
;;         ;; No amount change, do nothing
;;         true
;;       )
      
;;       ;; Update the listing in the map
;;       (map-set listings-ft { maker:contract-caller, contractAddr:(contract-of ft-asset-contract)}
;;         {
;;           maker: (get maker listing),
;;           taker: (get taker listing),
;;           amt: updated-amt,
;;           ft-asset-contract: (get ft-asset-contract listing),
;;           expiry: updated-expiry,
;;           price: updated-price,
;;           payment-asset-contract: (get payment-asset-contract listing)
;;         }
;;       )
      
;;       ;; Print update event
;;       (print {
;;         topic: "listing-updated",
;;         old-amt: current-amt,
;;         new-amt: updated-amt,
;;         new-price: updated-price,
;;         new-expiry: updated-expiry,
;;         maker: (get maker listing)
;;       })
      
;;       (ok true)
;;     )
;;   )
;; )


;; ;; Public function to purchase a listing using STX as payment
;; (define-public (fulfil-listing-ft-stx (ft-asset-contract <ft-trait>) (asset-owner principal) (amt uint))
;;  (let (
;;   ;; Verify the given listing ID exists
;;   (listing (unwrap! (map-get? listings-ft { maker: asset-owner, contractAddr:(contract-of ft-asset-contract)}) ERR_UNKNOWN_LISTING))
;;   ;; Set the ft's taker to the purchaser (caller of the function)
;;   (taker tx-sender)
;;   ;; Calculate remaining amount
;;   (remaining-amt (- (get amt listing) amt))
  
;;   ;; Calculate total payment (price per unit * amount)
;;   (total-payment (* (get price listing) amt))
;;   ;; Changed: Calculate transaction fee as percentage of total payment
;;   (tx-fee (calculate-transaction-fee total-payment))
;;   ;; Calculate total cost (payment + fee)
;;   (total-cost (+ total-payment tx-fee))
;;  )
;;   ;; Check if contract is paused
;;   (try! (assert-not-paused))
;;   ;; Validate that the purchase can be fulfilled
;;   (try! (is-protocol-caller fulfill-role contract-caller))
;;   ;; Check if requested amount is valid
;;   (asserts! (>= (get amt listing) amt) ERR_AMOUNT_IS_BIGGER) ;;remove
;;   ;; Check that payment asset is STX (none means STX)
;;   (asserts! (is-none (get payment-asset-contract listing)) ERR_PAYMENT_ASSET_MISMATCH) ;;remove and put in fulfill contact is-none important
  
;;   ;; Transfer the ft to the purchaser (caller of the function)
;;   (try! (as-contract (transfer-ft ft-asset-contract amt tx-sender taker)))  ;;transfer
  
;;   ;; Transfer the STX payment from the purchaser to the creator of the ft
;;   (try! (stx-transfer? total-payment taker (get maker listing))) ;;transfer
  
;;   ;; Transfer the transaction fee to the contract owner 
;;   (if (not (is-eq taker (var-get contract-owner)))
;;     (try! (stx-transfer? tx-fee taker (var-get contract-owner)))
;;     true
;;   ) ;;transfer
  
;;   ;; Update or remove the listing based on remaining amount
;;   (if (is-eq remaining-amt u0)
;;     ;; If no amount remains, delete the listing
;;     (begin
;;       (map-delete listings-ft { maker:contract-caller, contractAddr:(contract-of ft-asset-contract)})
;;       (print {
;;         topic: "listing-fulfilled-stx",
;;         amt: amt,
;;         remaining-amt: remaining-amt,
;;         total-payment: total-payment,
;;         tx-fee: tx-fee,
;;         fee-percentage: (var-get transaction-fee-bps),
;;         buyer: taker,
;;         seller: (get maker listing)
;;       })
;;       (ok true)
;;     )
;;     ;; If amount remains, update the listing
;;     (begin
;;       (map-set listings-ft { maker:contract-caller, contractAddr:(contract-of ft-asset-contract)}
;;         {
;;           maker: (get maker listing),
;;           taker: none,
;;           amt: remaining-amt,
;;           ft-asset-contract: (get ft-asset-contract listing),
;;           expiry: (get expiry listing),
;;           price: (get price listing),
;;           payment-asset-contract: (get payment-asset-contract listing)
;;         }
;;       )
;;       (print {
;;         topic: "listing-partially-fulfilled-stx",
;;         amt: amt,
;;         remaining-amt: remaining-amt,
;;         total-payment: total-payment,
;;         tx-fee: tx-fee,
;;         fee-percentage: (var-get transaction-fee-bps),
;;         buyer: taker,
;;         seller: (get maker listing)
;;       })
;;       (ok true)
;;     )
;;   )
;;  )
;; )

;; ;; Public function to purchase a listing using another fungible token as payment
;; (define-public (fulfil-ft-listing-ft
;;  (ft-asset-contract <ft-trait>)
;;  (payment-asset-contract <ft-trait>)
;;  (asset-owner principal)
;;  (amt uint)
;; )
;;  (let (
;;   ;; Verify the given listing ID exists
;;   (listing (unwrap! (map-get? listings-ft { maker: asset-owner, contractAddr:(contract-of ft-asset-contract)}) ERR_UNKNOWN_LISTING))
;;   ;; Set the ft's taker to the purchaser (caller of the function)
;;   (taker tx-sender)
;;   ;; Calculate remaining amount
;;   (remaining-amt (- (get amt listing) amt))
;;   ;; Calculate total payment (price per unit * amount)
;;   (total-payment (* (get price listing) amt))
;;   ;; Changed: Calculate transaction fee as percentage of total payment
;;   (tx-fee (calculate-transaction-fee total-payment))
;;  )
;;   ;; Check if contract is paused
;;   (try! (assert-not-paused))
;;   ;; Validate that the purchase can be fulfilled
;;   (try! (is-protocol-caller fulfill-role contract-caller))
;;   ;; Check if requested amount is valid
;;   (asserts! (>= (get amt listing) amt) ERR_AMOUNT_IS_BIGGER)
;;   ;; Check that payment asset contract matches
;;   (asserts! (is-eq 
;;     (some (contract-of payment-asset-contract)) 
;;     (get payment-asset-contract listing)
;;   ) ERR_PAYMENT_ASSET_MISMATCH) ;; remove this and put in fullfiill contract, some important
  
;;   ;; Transfer the ft to the purchaser (caller of the function)
;;   (try! (as-contract (transfer-ft ft-asset-contract amt tx-sender taker)))
  
;;   ;; Transfer the tokens as payment from the purchaser to the creator of the ft
;;   (try! (transfer-ft payment-asset-contract total-payment taker (get maker listing)))
  
;;   ;; Transfer the transaction fee to the contract owner (using same payment token)
;;   (if (not (is-eq taker (var-get contract-owner)))
;;     (try! (transfer-ft payment-asset-contract tx-fee taker (var-get contract-owner)))
;;     true
;;   ) ;;transfer
  
;;   ;; Update or remove the listing based on remaining amount
;;   (if (is-eq remaining-amt u0)
;;     ;; If no amount remains, delete the listing
;;     (begin
;;       (map-delete listings-ft { maker:contract-caller, contractAddr:(contract-of ft-asset-contract)})
;;       (print {
;;         topic: "listing-fulfilled-ft",
;;         amt: amt,
;;         remaining-amt: remaining-amt,
;;         total-payment: total-payment,
;;         tx-fee: tx-fee,
;;         fee-percentage: (var-get transaction-fee-bps),
;;         buyer: taker,
;;         seller: (get maker listing)
;;       })
;;       (ok true)
;;     )
;;     ;; If amount remains, update the listing
;;     (begin
;;       (map-set listings-ft { maker:contract-caller, contractAddr:(contract-of ft-asset-contract)}
;;         {
;;           maker: (get maker listing),
;;           taker: none,
;;           amt: remaining-amt,
;;           ft-asset-contract: (get ft-asset-contract listing),
;;           expiry: (get expiry listing),
;;           price: (get price listing),
;;           payment-asset-contract: (get payment-asset-contract listing)
;;         }
;;       )
;;       (print {
;;         topic: "listing-partially-fulfilled-ft",
;;         amt: amt,
;;         remaining-amt: remaining-amt,
;;         total-payment: total-payment,
;;         tx-fee: tx-fee,
;;         fee-percentage: (var-get transaction-fee-bps),
;;         buyer: taker,
;;         seller: (get maker listing)
;;       })
;;       (ok true)
;;     )
;;   )
;;  )
;; )

;; (define-public (update-protocol-contract
;; 		(contract-type (buff 1))
;; 		(new-contract principal)
;; 	)
;; 	(begin
;; 		;; Check that caller is protocol contract
;; 		(try! (is-protocol-caller admin-role contract-caller))
;; 		;; Update the protocol contract
;; 		(map-set active-protocol-contracts contract-type new-contract)
;; 		;; Update the protocol role
;; 		(map-set active-protocol-roles new-contract contract-type)
;; 		(print {
;; 			topic: "update-protocol-contract",
;; 			contract-type: contract-type,
;; 			new-contract: new-contract,
;; 		})
;; 		(ok true)
;; 	)
;; )


;; A ft marketplace that allows users to list ft for sale. They can specify the following:
;; - The ft token to sell.
;; - Listing expiry in block height.
;; - The payment asset, either STX or a SIP010 fungible token.
;; - The ft price in said payment asset.
;; - An optional intended taker. If set, only that principal will be able to fulfil the listing.
;;
;; Source: https://github.com/clarity-lang/book/tree/main/projects/tiny-market


(use-trait ft-trait 'STM6S3AESTK9NAYE3Z7RS00T11ER8JJCDNTKG711.sip-010-trait.sip-010-trait)



;; listing errors
(define-constant ERR_EXPIRY_IN_PAST (err u1000))
(define-constant ERR_PRICE_ZERO (err u1001))
(define-constant ERR_AMOUNT_ZERO (err u1002))
(define-constant ERR_NOT_ADMIN (err u1003))


;; cancelling and fulfiling errors
(define-constant ERR_UNKNOWN_LISTING (err u2000))
(define-constant ERR_UNAUTHORISED (err u2001))
(define-constant ERR_LISTING_EXPIRED (err u2002))
(define-constant ERR_FT_ASSET_MISMATCH (err u2003))
(define-constant ERR_PAYMENT_ASSET_MISMATCH (err u2004))
(define-constant ERR_MAKER_TAKER_EQUAL (err u2005))
(define-constant ERR_UNINTENDED_TAKER (err u2006))
(define-constant ERR_ASSET_CONTRACT_NOT_WHITELISTED (err u2007))
(define-constant ERR_PAYMENT_CONTRACT_NOT_WHITELISTED (err u2008))
(define-constant ERR_AMOUNT_IS_BIGGER (err u2009))

;; emergency and fee errors
(define-constant ERR_CONTRACT_PAUSED (err u3000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u3001))

(define-constant admin-role 0x00)
(define-constant fulfill-role 0x01) 

;; Emergency stop and transaction fee data variables
(define-data-var emergency-stop bool false)
;; Changed: Single percentage-based transaction fee (5% = 500 basis points)
(define-data-var transaction-fee-bps uint u500) ;; Default 5% = 500 basis points
(define-constant BPS-DENOM u10000) ;; denominator for basis points

;; Define a map data structure for the asset listings-ft
(define-map listings-ft
  uint
  {
    maker: principal,
    taker: (optional principal),
    amt: uint,
    ft-asset-contract: principal,
    expiry: uint,
    price: uint,
    payment-asset-contract: (optional principal)
  }
)

;; Used for unique IDs for each listing
(define-data-var listing-ft-nonce uint u0)


(define-data-var contract-owner principal tx-sender)
  
;; Function to calculate percentage-based fee
(define-private (calculate-transaction-fee (payment-amount uint))
  (/ (* payment-amount (var-get transaction-fee-bps)) BPS-DENOM)
)

;; admin function: update contract owner
(define-public (set-contract-owner (new-owner principal))
  (if (is-eq tx-sender (var-get contract-owner))
      (begin (var-set contract-owner new-owner) (ok true))
      ERR_UNAUTHORISED
  )
)


;; This marketplace requires any contracts used for assets or payments to be whitelisted
;; by the contract owner of this (marketplace) contract.
(define-map whitelisted-asset-contracts principal bool)
(map-set whitelisted-asset-contracts .mock-token true) ;;test
(map-set whitelisted-asset-contracts .non-whitelisted-ft true) ;;test



(define-map active-protocol-contracts (buff 1) principal)
(map-set active-protocol-contracts 0x00 .marketplace-admin)
(map-set active-protocol-contracts 0x01 .marketplace-fulfill)

(define-map active-protocol-roles principal (buff 1))
(map-set active-protocol-roles .marketplace-admin admin-role)
(map-set active-protocol-roles .marketplace-fulfill fulfill-role)

;; Emergency stop modifier - checks if contract is paused
(define-private (assert-not-paused)
  (begin
    (asserts! (not (var-get emergency-stop)) ERR_CONTRACT_PAUSED)
    (ok true)
  )
)

(define-read-only (get-contract-owner)
  (begin 
    (asserts! (is-eq (var-get contract-owner) contract-caller) ERR_NOT_ADMIN)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-listing-ft-nonce) 
  (ok (var-get listing-ft-nonce))
)


(define-read-only (get-listing-map (listing-id uint))
  (map-get? listings-ft listing-id)
)

(define-read-only (get-emergency-stop)
  (var-get emergency-stop)
)

;; Single function to get transaction fee percentage
(define-read-only (get-transaction-fee-bps)
  (var-get transaction-fee-bps)
)

;; Function to calculate fee for a given payment amount
(define-read-only (calculate-fee-for-amount (payment-amount uint))
  (calculate-transaction-fee payment-amount)
)

;; Function that checks if the given contract has been whitelisted.
(define-read-only (is-whitelisted (asset-contract principal))
  (default-to false (map-get? whitelisted-asset-contracts asset-contract))
)

(define-read-only (is-protocol-caller (contract-flag (buff 1)) (contract principal))
	(begin
		;; Check that contract-caller is an protocol contract
		(asserts! (is-eq (some contract) (map-get? active-protocol-contracts contract-flag)) ERR_UNAUTHORISED)
		;; Check that flag matches the contract-caller
		(asserts! (is-eq (some contract-flag) (map-get? active-protocol-roles contract)) ERR_UNAUTHORISED)
		(ok true)
	)
)

;; Admin functions for emergency stop and fees
(define-public (set-emergency-stop (paused bool))
  (begin
    (asserts! (is-eq (var-get contract-owner) tx-sender) ERR_UNAUTHORISED)
    (var-set emergency-stop paused)
    (print {
      topic: "emergency-stop-updated",
      paused: paused,
      caller: tx-sender
    })
    (ok true)
  )
)

;; Changed: Single function to set transaction fee percentage
(define-public (set-transaction-fee-bps (fee-bps uint))
  (begin
    (asserts! (is-eq (var-get contract-owner) tx-sender) ERR_UNAUTHORISED)
    (var-set transaction-fee-bps fee-bps)
    (print {
      topic: "transaction-fee-bps-updated",
      new-fee-bps: fee-bps,
      caller: tx-sender
    })
    (ok true)
  )
)

;; Only the contract owner of this (marketplace) contract can whitelist an asset contract.
(define-public (set-whitelisted (asset-contract principal) (whitelisted bool))
  (begin
    (try! (assert-not-paused))
    (asserts! (is-eq (var-get contract-owner) tx-sender) ERR_UNAUTHORISED)
    (map-set whitelisted-asset-contracts asset-contract whitelisted)
    (print {
            whitelisted: asset-contract,
            isWhitelisted: whitelisted
          })
    (ok true)
  )
)

;; Internal function to transfer fungible tokens from a sender to a given recipient.
(define-private (transfer-ft
  (token-contract <ft-trait>)
  (amount uint)
  (sender principal)
  (recipient principal)
)
  (contract-call? token-contract transfer amount sender recipient none)
)

;; Public function to list an asset along with its contract
(define-public (list-asset-ft
  (ft-asset-contract <ft-trait>)
  (ft-asset {
    taker: (optional principal),
    amt: uint,
    expiry: uint,
    price: uint,
    payment-asset-contract: (optional principal)
  })
)
  (let ((listing-id (var-get listing-ft-nonce)))
    ;; Check if contract is paused
    (try! (assert-not-paused))
    ;; Verify that the contract of this asset is whitelisted
    (asserts! (is-whitelisted (contract-of ft-asset-contract)) ERR_ASSET_CONTRACT_NOT_WHITELISTED)
    ;; Verify that the asset is not expired
    ;; (asserts! (> (get expiry ft-asset) burn-block-height) ERR_EXPIRY_IN_PAST)
    ;; Verify that the asset price is greater than zero
    (asserts! (> (get price ft-asset) u0) ERR_PRICE_ZERO)
    ;; Verify that the asset amt is greater than zero
    (asserts! (> (get amt ft-asset) u0) ERR_AMOUNT_ZERO)

    ;; Verify that the contract of the payment is whitelisted
    (asserts! (match (get payment-asset-contract ft-asset)
      payment-asset
      (is-whitelisted payment-asset)
      true
    ) ERR_PAYMENT_CONTRACT_NOT_WHITELISTED)
    ;; Transfer the FT ownership to this contract's principal
    (try! (transfer-ft
      ft-asset-contract
      (get amt ft-asset)
      tx-sender
      (as-contract tx-sender)
    ))
    ;; List the FT in the listings map
    (map-set listings-ft listing-id (merge
      { maker: tx-sender, ft-asset-contract: (contract-of ft-asset-contract) }
      ft-asset
    ))
    ;; Increment the nonce to use for the next unique listing ID
    (var-set listing-ft-nonce (+ listing-id u1))

    (print {
        topic: "listing-creation",
        listing-id: listing-id,
        amount: (get amt ft-asset),
        price: (get price ft-asset),
        expiry: (get expiry ft-asset),
        maker: tx-sender,
        taker: (get taker ft-asset),
        asset-contract: ft-asset-contract,
        payment-asset-contract: (get payment-asset-contract ft-asset)
      })

    ;; Return the created listing ID
    (ok true)
  )
)

(define-public (cancel-listing-ft (listing-id uint) (ft-asset-contract <ft-trait>))
  (let (
    (listing (unwrap! (map-get? listings-ft listing-id) ERR_UNKNOWN_LISTING))
    (maker (get maker listing))
  )
    ;; Verify that the caller of the function is the creator of the FT to be cancelled
    (asserts! (is-eq maker tx-sender) ERR_UNAUTHORISED)
    ;; Verify that the asset contract to use is the same one that the FT uses
    (asserts! (is-eq
      (get ft-asset-contract listing)
      (contract-of ft-asset-contract)
    ) ERR_FT_ASSET_MISMATCH)
    ;; Delete the listing
    (map-delete listings-ft listing-id)
    ;; Transfer the FT from this contract's principal back to the creator's principal
    (try! (as-contract (transfer-ft ft-asset-contract (get amt listing) tx-sender maker)))

    (print {
      listing-id: listing-id,
      topic: "Cancel listing",
      ft-asset-contract: ft-asset-contract
    })

    (ok true)

  )
)


;; Public function to update a listing (only callable by the listing's maker)
(define-public (update-listing-ft 
    (listing-id uint)
    (ft-asset-contract <ft-trait>)
    (new-amt (optional uint)) 
    (new-price (optional uint)) 
    (new-expiry (optional uint))
  )
  (let (
    ;; Fetch the listing, or fail if not found
    (listing (unwrap! (map-get? listings-ft listing-id) ERR_UNKNOWN_LISTING))
    (current-amt (get amt listing))
  )
    ;; Check if contract is paused
    (try! (assert-not-paused))
    ;; Ensure only the maker can update their listing
    (asserts! (is-eq tx-sender (get maker listing)) ERR_UNAUTHORISED)

    ;; Verify that the asset contract matches
    (asserts! (is-eq
      (get ft-asset-contract listing)
      (contract-of ft-asset-contract)
    ) ERR_FT_ASSET_MISMATCH)
    
    (let (
      ;; Use new values if provided, otherwise keep old values
      (updated-amt (default-to current-amt new-amt))
      (updated-price (default-to (get price listing) new-price))
      (updated-expiry (default-to (get expiry listing) new-expiry))
    )
      ;; Validate that updated amount is not zero
      (asserts! (> updated-amt u0) ERR_AMOUNT_ZERO)
      ;; Validate that updated price is not zero
      (asserts! (> updated-price u0) ERR_PRICE_ZERO)
      ;; Handle amount changes - transfer tokens if needed
      (if (not (is-eq updated-amt current-amt))
        (if (> updated-amt current-amt)
          ;; If increasing amount, user needs to transfer more tokens to contract
          (try! (transfer-ft
            ft-asset-contract
            (- updated-amt current-amt)
            tx-sender
            (as-contract tx-sender)
          ))
          ;; If decreasing amount, transfer excess tokens back to user
          (try! (as-contract (transfer-ft
            ft-asset-contract
            (- current-amt updated-amt)
            tx-sender
            (get maker listing)
          )))
        )
        ;; No amount change, do nothing
        true
      )
      
      ;; Update the listing in the map
      (map-set listings-ft listing-id
        {
          maker: (get maker listing),
          taker: (get taker listing),
          amt: updated-amt,
          ft-asset-contract: (get ft-asset-contract listing),
          expiry: updated-expiry,
          price: updated-price,
          payment-asset-contract: (get payment-asset-contract listing)
        }
      )
      
      ;; Print update event
      (print {
        topic: "listing-updated",
        listing-id: listing-id,
        old-amt: current-amt,
        new-amt: updated-amt,
        new-price: updated-price,
        new-expiry: updated-expiry,
        maker: (get maker listing)
      })
      
      (ok true)
    )
  )
)


;; Public function to purchase a listing using STX as payment
(define-public (fulfil-listing-ft-stx (listing-id uint) (ft-asset-contract <ft-trait>) (amt uint))
 (let (
  ;; Verify the given listing ID exists
  (listing (unwrap! (map-get? listings-ft listing-id) ERR_UNKNOWN_LISTING))
  ;; Set the ft's taker to the purchaser (caller of the function)
  (taker tx-sender)
  ;; Calculate remaining amount
  (remaining-amt (- (get amt listing) amt))
  
  ;; Calculate total payment (price per unit * amount)
  (total-payment (* (get price listing) amt))
  ;; Changed: Calculate transaction fee as percentage of total payment
  (tx-fee (calculate-transaction-fee total-payment))
  ;; Calculate total cost (payment + fee)
  (total-cost (+ total-payment tx-fee))
 )
  ;; Check if contract is paused
  (try! (assert-not-paused))
  ;; Validate that the purchase can be fulfilled
  (try! (is-protocol-caller fulfill-role contract-caller))
  ;; Check if requested amount is valid
  (asserts! (>= (get amt listing) amt) ERR_AMOUNT_IS_BIGGER) ;;remove
  ;; Check that payment asset is STX (none means STX)
  (asserts! (is-none (get payment-asset-contract listing)) ERR_PAYMENT_ASSET_MISMATCH) ;;remove and put in fulfill contact is-none important
  
  ;; Transfer the ft to the purchaser (caller of the function)
  (try! (as-contract (transfer-ft ft-asset-contract amt tx-sender taker)))  ;;transfer
  
  ;; Transfer the STX payment from the purchaser to the creator of the ft
  (try! (stx-transfer? total-payment taker (get maker listing))) ;;transfer
  
  ;; Transfer the transaction fee to the contract owner 
  (if (not (is-eq taker (var-get contract-owner)))
    (try! (stx-transfer? tx-fee taker (var-get contract-owner)))
    true
  ) ;;transfer
  
  ;; Update or remove the listing based on remaining amount
  (if (is-eq remaining-amt u0)
    ;; If no amount remains, delete the listing
    (begin
      (map-delete listings-ft listing-id)
      (print {
        topic: "listing-fulfilled-stx",
        listing-id: listing-id,
        amt: amt,
        remaining-amt: remaining-amt,
        total-payment: total-payment,
        tx-fee: tx-fee,
        fee-percentage: (var-get transaction-fee-bps),
        buyer: taker,
        seller: (get maker listing)
      })
      (ok true)
    )
    ;; If amount remains, update the listing
    (begin
      (map-set listings-ft listing-id
        {
          maker: (get maker listing),
          taker: none,
          amt: remaining-amt,
          ft-asset-contract: (get ft-asset-contract listing),
          expiry: (get expiry listing),
          price: (get price listing),
          payment-asset-contract: (get payment-asset-contract listing)
        }
      )
      (print {
        topic: "listing-partially-fulfilled-stx",
        listing-id: listing-id,
        amt: amt,
        remaining-amt: remaining-amt,
        total-payment: total-payment,
        tx-fee: tx-fee,
        fee-percentage: (var-get transaction-fee-bps),
        buyer: taker,
        seller: (get maker listing)
      })
      (ok true)
    )
  )
 )
)

;; Public function to purchase a listing using another fungible token as payment
(define-public (fulfil-ft-listing-ft
 (listing-id uint)
 (ft-asset-contract <ft-trait>)
 (payment-asset-contract <ft-trait>)
 (amt uint)
)
 (let (
  ;; Verify the given listing ID exists
  (listing (unwrap! (map-get? listings-ft listing-id) ERR_UNKNOWN_LISTING))
  ;; Set the ft's taker to the purchaser (caller of the function)
  (taker tx-sender)
  ;; Calculate remaining amount
  (remaining-amt (- (get amt listing) amt))
  ;; Calculate total payment (price per unit * amount)
  (total-payment (* (get price listing) amt))
  ;; Changed: Calculate transaction fee as percentage of total payment
  (tx-fee (calculate-transaction-fee total-payment))
 )
  ;; Check if contract is paused
  (try! (assert-not-paused))
  ;; Validate that the purchase can be fulfilled
  (try! (is-protocol-caller fulfill-role contract-caller))
  ;; Check if requested amount is valid
  (asserts! (>= (get amt listing) amt) ERR_AMOUNT_IS_BIGGER)
  ;; Check that payment asset contract matches
  (asserts! (is-eq 
    (some (contract-of payment-asset-contract)) 
    (get payment-asset-contract listing)
  ) ERR_PAYMENT_ASSET_MISMATCH) ;; remove this and put in fullfiill contract, some important
  
  ;; Transfer the ft to the purchaser (caller of the function)
  (try! (as-contract (transfer-ft ft-asset-contract amt tx-sender taker)))
  
  ;; Transfer the tokens as payment from the purchaser to the creator of the ft
  (try! (transfer-ft payment-asset-contract total-payment taker (get maker listing)))
  
  ;; Transfer the transaction fee to the contract owner (using same payment token)
  (if (not (is-eq taker (var-get contract-owner)))
    (try! (transfer-ft payment-asset-contract tx-fee taker (var-get contract-owner)))
    true
  ) ;;transfer
  
  ;; Update or remove the listing based on remaining amount
  (if (is-eq remaining-amt u0)
    ;; If no amount remains, delete the listing
    (begin
      (map-delete listings-ft listing-id)
      (print {
        topic: "listing-fulfilled-ft",
        listing-id: listing-id,
        amt: amt,
        remaining-amt: remaining-amt,
        total-payment: total-payment,
        tx-fee: tx-fee,
        fee-percentage: (var-get transaction-fee-bps),
        buyer: taker,
        seller: (get maker listing)
      })
      (ok true)
    )
    ;; If amount remains, update the listing
    (begin
      (map-set listings-ft listing-id
        {
          maker: (get maker listing),
          taker: none,
          amt: remaining-amt,
          ft-asset-contract: (get ft-asset-contract listing),
          expiry: (get expiry listing),
          price: (get price listing),
          payment-asset-contract: (get payment-asset-contract listing)
        }
      )
      (print {
        topic: "listing-partially-fulfilled-ft",
        listing-id: listing-id,
        amt: amt,
        remaining-amt: remaining-amt,
        total-payment: total-payment,
        tx-fee: tx-fee,
        fee-percentage: (var-get transaction-fee-bps),
        buyer: taker,
        seller: (get maker listing)
      })
      (ok true)
    )
  )
 )
)

(define-public (update-protocol-contract
		(contract-type (buff 1))
		(new-contract principal)
	)
	(begin
    ;; Check if contract is paused
    (try! (assert-not-paused))
		;; Check that caller is protocol contract
		(try! (is-protocol-caller admin-role contract-caller))
		;; Update the protocol contract
		(map-set active-protocol-contracts contract-type new-contract)
		;; Update the protocol role
		(map-set active-protocol-roles new-contract contract-type)
		(print {
			topic: "update-protocol-contract",
			contract-type: contract-type,
			new-contract: new-contract,
		})
		(ok true)
	)
)