;; A ft marketplace that allows users to list ft for sale. They can specify the following:
;; - The ft token to sell.
;; - Listing expiry in block height.
;; - The payment asset, either STX or a SIP010 fungible token.
;; - The ft price in said payment asset.
;; - An optional intended taker. If set, only that principal will be able to fulfil the listing.
;;
;; Source: https://github.com/clarity-lang/book/tree/main/projects/tiny-market


(use-trait ft-trait 'STM6S3AESTK9NAYE3Z7RS00T11ER8JJCDNTKG711.sip-010-trait.sip-010-trait)
(use-trait call-owner .token-trait.token-trait)



;; listing errors
(define-constant ERR_EXPIRY_IN_PAST (err u1000))
(define-constant ERR_PRICE_ZERO (err u1001))
(define-constant ERR_AMOUNT_ZERO (err u1002))
(define-constant ERR_NOT_ADMIN (err u1003))
(define-constant ERR_AMOUNT_NOT_EQUAL (err u1004))
(define-constant ERR_AMOUNT_NOT_FOUND (err u1005))
(define-constant ERR_NOT_EXPIRY (err u1000))




;; cancelling and fulfiling errors
(define-constant ERR_UNKNOWN_LISTING (err u2000))
(define-constant ERR_UNAUTHORISED (err u2001))
(define-constant ERR_LISTING_EXPIRED (err u2002))
(define-constant ERR_FT_ASSET_MISMATCH (err u2003))
(define-constant ERR_PAYMENT_ASSET_MISMATCH (err u2004))
(define-constant ERR_MAKER_taker_EQUAL (err u2005))
(define-constant ERR_UNINTENDED_taker (err u2006))
(define-constant ERR_ASSET_CONTRACT_NOT_WHITELISTED (err u2007))
(define-constant ERR_PAYMENT_CONTRACT_NOT_WHITELISTED (err u2008))
(define-constant ERR_AMOUNT_IS_BIGGER (err u2009))
(define-constant ERR_USER_BOUGHT_NOTHING (err u2010))
(define-constant ERR_LISTING_EXIST (err u2011))
(define-constant ERR_MILESTONE_NOT_COMP (err u2012))
(define-constant ERR_BIGGER_CURRENT_MILESTONE (err u2013))
(define-constant ERR_NO_PAYMENT_CONTRACT (err u2014))
(define-constant ERR_CLAIM_AMOUNT_ZERO (err u2015))




;; emergency and fee errors
(define-constant ERR_CONTRACT_PAUSED (err u3000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u3001))

(define-constant ERR_FT_AND_CALL_NOT_EQUAL (err u3002))
(define-constant ERR_NOT_ASSET_OWNER (err u3003))
(define-constant ERR_GETTING_ASSET_OWNER (err u3004))




(define-constant admin-role 0x00)
(define-constant fulfill-role 0x01)

;; Emergency stop and transaction fee data variables
(define-data-var emergency-stop bool false)
;; Changed: Single percentage-based transaction fee (5% = 500 basis points)
(define-data-var transaction-fee-bps uint u500) ;; Default 5% = 500 basis points
(define-constant BPS-DENOM u10000) ;; denominator for basis points


;; Define a map data structure for the asset listings-ft
(define-map listings-ft
  {maker: principal, contractAddr: principal}
  {
    maker: principal,
    amt: uint,
    ft-asset-contract: principal,
    expiry: uint,
    price: uint,
    payment-asset-contract: (optional principal),
    milestone: uint,
    total-collected: uint
  }
)



(define-map asset-m-pool 
  {investor: principal, asset: principal}  
  {
    token-amt: uint, 
    invested-amt: uint, 
    investedMilestone: uint,
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
(define-map whitelisted-asset-contracts principal {isWhitelisted: bool, amount: uint, divide: uint})

(define-map whitelisted-payment-contracts principal bool)
;; (map-set whitelisted-asset-contracts .mock-token true) ;;test
;; (map-set whitelisted-asset-contracts .non-whitelisted-ft true) ;;test



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


(define-read-only (get-listing-map (assetOwner principal) (ft-asset-contract principal))
  (map-get? listings-ft { maker: assetOwner, contractAddr: ft-asset-contract})
)

(define-read-only (get-user-investment-map (assetOwner principal) (ft-asset-contract principal))
  (map-get? asset-m-pool { investor: assetOwner, asset: ft-asset-contract})
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
  (let ((contract (map-get? whitelisted-asset-contracts asset-contract))
        (whitelisted (get isWhitelisted contract))
      ) 
      (default-to false whitelisted)
  )
)

(define-read-only (is-whitelisted-payment (payment-contract principal))
  (default-to false (map-get? whitelisted-payment-contracts payment-contract))
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
;; test
(define-public (set-whitelisted (asset-contract principal) (whitelisted bool) (divide uint) (amount (optional uint)))
  (begin
    (try! (assert-not-paused))
    (asserts! (is-eq (var-get contract-owner) contract-caller) ERR_UNAUTHORISED)
    (match amount asset-amount 
       (begin 
      (map-set whitelisted-asset-contracts asset-contract {isWhitelisted: whitelisted, amount: asset-amount, divide: divide})
      (print {
              whitelisted-asset: asset-contract,
              isWhitelisted: whitelisted
            })
      (ok true))
       (begin
        (map-set whitelisted-payment-contracts asset-contract whitelisted)
      (print {
              whitelisted-payment: asset-contract,
              isWhitelisted: whitelisted
            })
      (ok true))
    )
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
  (owner-asset-contract <call-owner>)
  (ft-asset {
    amt: uint,
    expiry: uint,
    price: uint,
    payment-asset-contract: (optional principal)
  })
)
  
  (begin  
      ;; Check if contract is paused
      (try! (assert-not-paused))
      (asserts! (is-eq (contract-of ft-asset-contract) (contract-of owner-asset-contract)) ERR_FT_AND_CALL_NOT_EQUAL)
      (let (
        ;; (listing-id (var-get listing-ft-nonce))
            (asset-owner (unwrap! (contract-call? owner-asset-contract get-owner) ERR_GETTING_ASSET_OWNER))
            (whitelisted-info (map-get? whitelisted-asset-contracts (contract-of ft-asset-contract)))
            (listing (is-none (map-get? listings-ft { maker: asset-owner, contractAddr: (contract-of ft-asset-contract)}))) 
            (is-eq-amount (unwrap! (get amount whitelisted-info) ERR_AMOUNT_NOT_FOUND))
            (ft-amt (get amt ft-asset))
      )
        (asserts! listing ERR_LISTING_EXIST)
        (asserts! (is-eq is-eq-amount ft-amt) ERR_AMOUNT_NOT_EQUAL)
          
        (asserts! (is-eq asset-owner contract-caller) ERR_NOT_ASSET_OWNER)
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
          (is-whitelisted-payment payment-asset)
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
        (map-set listings-ft {maker: tx-sender, contractAddr: (contract-of ft-asset-contract)} (merge
          { maker: tx-sender, ft-asset-contract: (contract-of ft-asset-contract), milestone: u0, total-collected: u0 }
          ft-asset
        ))
        ;; Increment the nonce to use for the next unique listing ID
        ;; (var-set listing-ft-nonce (+ listing-id u1))

        (print {
            topic: "listing-creation",
            ;; listing-id: listing-id,
            amount: (get amt ft-asset),
            price: (get price ft-asset),
            expiry: (get expiry ft-asset),
            maker: tx-sender,
            asset-contract: ft-asset-contract,
            payment-asset-contract: (get payment-asset-contract ft-asset)
          })

        (ok true)
      )
  
  )
)

(define-public (cancel-listing-ft (ft-asset-contract <ft-trait>))
  (let (
    (listing (unwrap! (map-get? listings-ft { maker:contract-caller, contractAddr:(contract-of ft-asset-contract)} ) ERR_UNKNOWN_LISTING))
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
    (map-delete listings-ft { maker:contract-caller, contractAddr:(contract-of ft-asset-contract)} )
    ;; Transfer the FT from this contract's principal back to the creator's principal
    (try! (as-contract (transfer-ft ft-asset-contract (get amt listing) tx-sender maker)))

    (print {
      
      topic: "Cancel listing",
      canceller: contract-caller,
      ft-asset-contract: ft-asset-contract
    })

    (ok true)

  )
)


;; Public function to update a listing (only callable by the listing's maker)
(define-public (update-listing-ft 
    
    (ft-asset-contract <ft-trait>)
    ;; (new-amt (optional uint)) 
    ;; (new-price (optional uint)) 
    (new-expiry uint)
  )
  (let (
    ;; Fetch the listing, or fail if not found
    (listing (unwrap! (map-get? listings-ft { maker: contract-caller, contractAddr: (contract-of ft-asset-contract)}) ERR_UNKNOWN_LISTING))
    (current-amt (get amt listing))
    (current-price (get price listing))
  )
    ;; Check if contract is paused
    (try! (assert-not-paused))
    ;; Ensure only the maker can update their listing
    (asserts! (is-eq contract-caller (get maker listing)) ERR_UNAUTHORISED)

    ;; Verify that the asset contract matches
    (asserts! (is-eq
      (get ft-asset-contract listing)
      (contract-of ft-asset-contract)
    ) ERR_FT_ASSET_MISMATCH)
    
    (let (
      ;; Use new values if provided, otherwise keep old values
      ;; (updated-amt (default-to current-amt new-amt))
      ;; (updated-price (default-to (get price listing) new-price))
      (current-expiry (get expiry listing))
    )
      (asserts! (>= current-expiry stacks-block-height) ERR_NOT_EXPIRY)
      (asserts! (> new-expiry stacks-block-height) ERR_EXPIRY_IN_PAST)
      
      ;; Validate that updated amount is not zero
      ;; (asserts! (> updated-amt u0) ERR_AMOUNT_ZERO)
      ;; Validate that updated price is not zero
      ;; (asserts! (> updated-price u0) ERR_PRICE_ZERO)
      ;; Handle amount changes - transfer tokens if needed
      ;; (if (not (is-eq updated-amt current-amt))
      ;;   (if (> updated-amt current-amt)
      ;;     ;; If increasing amount, user needs to transfer more tokens to contract
      ;;     (try! (transfer-ft
      ;;       ft-asset-contract
      ;;       (- updated-amt current-amt)
      ;;       tx-sender
      ;;       (as-contract tx-sender)
      ;;     ))
      ;;     ;; If decreasing amount, transfer excess tokens back to user
      ;;     (try! (as-contract (transfer-ft
      ;;       ft-asset-contract
      ;;       (- current-amt updated-amt)
      ;;       tx-sender
      ;;       (get maker listing)
      ;;     )))
      ;;   )
      ;;   ;; No amount change, do nothing
      ;;   true
      ;; )
      
      ;; Update the listing in the map
      (map-set listings-ft { maker: contract-caller, contractAddr:(contract-of ft-asset-contract)}
        {
          maker: (get maker listing),
          amt: current-amt,
          ft-asset-contract: (get ft-asset-contract listing),
          expiry: new-expiry,
          price: current-price,
          payment-asset-contract: (get payment-asset-contract listing),
          milestone: (get milestone listing),
          total-collected: (get total-collected listing)
        }
      )
      
      ;; Print update event
      (print {
        topic: "listing-updated",
        new-expiry: new-expiry,
        maker: (get maker listing)
      })
      
      (ok true)
    )
  )
)




(define-public (reserve (ft-asset-contract principal) (asset-owner principal) (amt uint)) 
  (let (
    ;; listing information
    (listing (unwrap! (map-get? listings-ft { maker: asset-owner, contractAddr: ft-asset-contract}) ERR_UNKNOWN_LISTING))
    

    (listing-price (get price listing))

    (listing-total-collected (get total-collected listing))

    ;; token of the listing info got from whitelisted
    (token-info (unwrap! (map-get? whitelisted-asset-contracts ft-asset-contract) ERR_UNKNOWN_LISTING))

    

    ;; initial token amount ;; help in the dividing the milestone amount because it is static
    (total-token-amt (get amount token-info))


    ;; how many milestone
    (milestone (get divide token-info))

    (divide-token-by (/ total-token-amt milestone))

    
    ;; Calculate remaining amount
    (remaining-amt (- (get amt listing) amt))

    (bought-amt (- total-token-amt remaining-amt))

    (complete-milestone (/ bought-amt divide-token-by))

    (listing-milestone (get milestone listing))

    (user-side-milestone-progress (if (is-eq complete-milestone milestone) complete-milestone (+ complete-milestone u1))) 

    ;; Amount user have invested in token
    (user-amt-pool (default-to {token-amt: u0, invested-amt: u0, investedMilestone: user-side-milestone-progress} (map-get? asset-m-pool {investor: tx-sender, asset: ft-asset-contract})))
    
    (user-token-amount (get token-amt user-amt-pool))

    (invested-amount (get invested-amt user-amt-pool))

    (invested-milestone (get investedMilestone user-amt-pool))

    ;; (divide-last-investment-milestone (if (is-eq complete-milestone u0) u1 complete-milestone))
    
    ;; Calculate total payment (price per unit * amount)
    (total-payment (* listing-price amt))

    (first-milestone-inside-amt (- divide-token-by u1))

    (milestone-inside-amt (+ (* first-milestone-inside-amt user-side-milestone-progress) (- user-side-milestone-progress u1) ))
    
  ) 
    (try! (assert-not-paused))
    (try! (is-protocol-caller fulfill-role contract-caller))
    
    ;; Check that payment asset is STX (none means STX)
    (asserts! (is-none (get payment-asset-contract listing)) ERR_PAYMENT_ASSET_MISMATCH)
    (asserts! (is-eq listing-milestone complete-milestone) ERR_MILESTONE_NOT_COMP)
    (asserts! (is-eq user-side-milestone-progress invested-milestone) ERR_MILESTONE_NOT_COMP)
    (try! (stx-transfer? total-payment tx-sender (as-contract tx-sender)))
    
    (if (is-eq milestone complete-milestone)
        (begin
          (map-set listings-ft 
            { 
              maker: asset-owner, 
              contractAddr: ft-asset-contract
            }

            {
              maker: (get maker listing),
              amt: remaining-amt, 
              ft-asset-contract: (get ft-asset-contract listing),
              expiry: (get expiry listing),
              price: listing-price,
              payment-asset-contract: none,
              milestone: complete-milestone,
              total-collected: (+ listing-total-collected (* first-milestone-inside-amt listing-price))
            }
          )
          
          (map-set asset-m-pool 
            {
              investor: tx-sender, 
              asset: ft-asset-contract
            } 
                          
            {
              token-amt:(+ user-token-amount amt),
              invested-amt: (+ total-payment invested-amount),
              investedMilestone: invested-milestone
            }
          )

          (print 
            {
              invested-amount: (+ total-payment invested-amount),
              token-amount: amt
            }
          )

          (ok true) 
        )
    
        (if (is-eq milestone-inside-amt bought-amt)
        (begin
          (map-set listings-ft 
            { 
              maker: asset-owner, 
              contractAddr: ft-asset-contract
            }

            {
              maker: (get maker listing),
              amt: remaining-amt, 
              ft-asset-contract: (get ft-asset-contract listing),
              expiry: (get expiry listing),
              price: listing-price,
              payment-asset-contract: none,
              milestone: (+ complete-milestone u1),
              total-collected: (+ listing-total-collected (* first-milestone-inside-amt listing-price))
            }
          )
          
          (map-set asset-m-pool 
            {
              investor: tx-sender, 
              asset: ft-asset-contract
            } 
                          
            {
              token-amt:(+ user-token-amount amt),
              invested-amt: (+ total-payment invested-amount),
              investedMilestone: invested-milestone
            }
          )

          (print 
            {
              invested-amount: (+ total-payment invested-amount),
              token-amount: amt
            }
          )

          (ok true) 
        )

        (begin 
          (asserts! (> milestone-inside-amt bought-amt) ERR_BIGGER_CURRENT_MILESTONE)
          (map-set listings-ft 
            { 
              maker: asset-owner, 
              contractAddr: ft-asset-contract
            }

            {
              maker: (get maker listing),
              amt: remaining-amt,
              ft-asset-contract: (get ft-asset-contract listing),
              expiry: (get expiry listing),
              price: listing-price,
              payment-asset-contract: none,
              milestone: complete-milestone,
              total-collected: listing-total-collected
            }
          )
          
          (map-set asset-m-pool 
            {
              investor: tx-sender, 
              asset: ft-asset-contract
            } 
                          
            {
              token-amt:(+ user-token-amount amt),
              invested-amt: (+ total-payment invested-amount),
              investedMilestone: invested-milestone
            }
          )

          (print 
            {
              invested-amount: (+ total-payment invested-amount),
              token-amount: amt,
              listing-remaining-amt: remaining-amt,
              print-path: u1
            }
          )

          (ok true)
        
        )

      )
    )
    

    

  )
)



;; (if (is-eq milestone-inside-amt bought-amt)
;;       (begin
;;         (map-set listings-ft 
;;           { 
;;             maker: asset-owner, 
;;             contractAddr: ft-asset-contract
;;           }

;;           {
;;             maker: (get maker listing),
;;             amt: remaining-amt,
;;             ft-asset-contract: (get ft-asset-contract listing),
;;             expiry: (get expiry listing),
;;             price: (get price listing),
;;             payment-asset-contract: (get payment-asset-contract listing),
;;             milestone: (+ complete-milestone u1),
;;             total-collected: (+ total-collect total-payment)

;;           }
;;         )
        
;;         (map-set asset-m-pool 
;;           {
;;             investor: tx-sender, 
;;             asset: ft-asset-contract
;;           } 
                        
;;           {
;;             token-amt:(+ user-token-amount amt),
;;             invested-amt: (+ total-payment invested-amount),
;;             investedMilestone: invested-milestone
;;           }
;;         )

;;         (print 
;;           {
;;             invested-amount: (+ total-payment invested-amount),
;;             token-amount: amt
;;           }
;;         )

;;         (ok true) 
;;       )

;;       (begin 
;;         (asserts! (> milestone-inside-amt bought-amt) ERR_BIGGER_CURRENT_MILESTONE)
;;         (map-set listings-ft 
;;           { 
;;             maker: asset-owner, 
;;             contractAddr: ft-asset-contract
;;           }

;;           {
;;             maker: (get maker listing),
;;             amt: remaining-amt,
;;             ft-asset-contract: (get ft-asset-contract listing),
;;             expiry: (get expiry listing),
;;             price: (get price listing),
;;             payment-asset-contract: (get payment-asset-contract listing),
;;             milestone: complete-milestone,
;;             total-collected: (+ total-collect total-payment)
;;           }
;;         )
        
;;         (map-set asset-m-pool 
;;           {
;;             investor: tx-sender, 
;;             asset: ft-asset-contract
;;           } 
                        
;;           {
;;             token-amt:(+ user-token-amount amt),
;;             invested-amt: (+ total-payment invested-amount),
;;             investedMilestone: invested-milestone
;;           }
;;         )

;;         (print 
;;           {
;;             invested-amount: (+ total-payment invested-amount),
;;             token-amount: amt
;;           }
;;         )

;;         (ok true)
      
;;       )

;;     )


(define-public (reserve-using-ft (ft-asset-contract principal) (asset-owner principal) (payment-contract <ft-trait>) (amt uint)) 
  (let (
    ;; listing information
    (listing (unwrap! (map-get? listings-ft { maker: asset-owner, contractAddr: ft-asset-contract}) ERR_UNKNOWN_LISTING))
    

    (listing-price (get price listing))

    (listing-total-collected (get total-collected listing))

    ;; token of the listing info got from whitelisted
    (token-info (unwrap! (map-get? whitelisted-asset-contracts ft-asset-contract) ERR_UNKNOWN_LISTING))

    

    ;; initial token amount ;; help in the dividing the milestone amount because it is static
    (total-token-amt (get amount token-info))


    ;; how many milestone
    (milestone (get divide token-info))

    (divide-token-by (/ total-token-amt milestone))

    
    ;; Calculate remaining amount
    (remaining-amt (- (get amt listing) amt))

    (bought-amt (- total-token-amt remaining-amt))

    (complete-milestone (/ bought-amt divide-token-by))

    (listing-milestone (get milestone listing))

    (user-side-milestone-progress (if (is-eq complete-milestone milestone) complete-milestone (+ complete-milestone u1))) 

    ;; Amount user have invested in token
    (user-amt-pool (default-to {token-amt: u0, invested-amt: u0, investedMilestone: user-side-milestone-progress} (map-get? asset-m-pool {investor: tx-sender, asset: ft-asset-contract})))
    
    (user-token-amount (get token-amt user-amt-pool))

    (invested-amount (get invested-amt user-amt-pool))

    (invested-milestone (get investedMilestone user-amt-pool))

    ;; (divide-last-investment-milestone (if (is-eq complete-milestone u0) u1 complete-milestone))
    
    ;; Calculate total payment (price per unit * amount)
    (total-payment (* listing-price amt))

    (first-milestone-inside-amt (- divide-token-by u1))

    (milestone-inside-amt (+ (* first-milestone-inside-amt user-side-milestone-progress) (- user-side-milestone-progress u1) ))
    
  ) 
    (try! (assert-not-paused))
    (try! (is-protocol-caller fulfill-role contract-caller))
    

    
    (asserts! (is-eq listing-milestone complete-milestone) ERR_MILESTONE_NOT_COMP)
    (asserts! (is-eq user-side-milestone-progress invested-milestone) ERR_MILESTONE_NOT_COMP)
    (try! (transfer-ft payment-contract total-payment tx-sender (as-contract tx-sender)))
    
    (if (is-eq milestone complete-milestone)
        (begin
          (map-set listings-ft 
            { 
              maker: asset-owner, 
              contractAddr: ft-asset-contract
            }

            {
              maker: (get maker listing),
              amt: remaining-amt, 
              ft-asset-contract: (get ft-asset-contract listing),
              expiry: (get expiry listing),
              price: listing-price,
              payment-asset-contract: (get payment-asset-contract listing),
              milestone: complete-milestone,
              total-collected: (+ listing-total-collected (* first-milestone-inside-amt listing-price))
            }
          )
          
          (map-set asset-m-pool 
            {
              investor: tx-sender, 
              asset: ft-asset-contract
            } 
                          
            {
              token-amt:(+ user-token-amount amt),
              invested-amt: (+ total-payment invested-amount),
              investedMilestone: invested-milestone
            }
          )

          (print 
            {
              invested-amount: (+ total-payment invested-amount),
              token-amount: amt
            }
          )

          (ok true) 
        )
    
        (if (is-eq milestone-inside-amt bought-amt)
        (begin
          (map-set listings-ft 
            { 
              maker: asset-owner, 
              contractAddr: ft-asset-contract
            }

            {
              maker: (get maker listing),
              amt: remaining-amt, 
              ft-asset-contract: (get ft-asset-contract listing),
              expiry: (get expiry listing),
              price: listing-price,
              payment-asset-contract: (get payment-asset-contract listing),
              milestone: (+ complete-milestone u1),
              total-collected: (+ listing-total-collected (* first-milestone-inside-amt listing-price))
            }
          )
          
          (map-set asset-m-pool 
            {
              investor: tx-sender, 
              asset: ft-asset-contract
            } 
                          
            {
              token-amt:(+ user-token-amount amt),
              invested-amt: (+ total-payment invested-amount),
              investedMilestone: invested-milestone
            }
          )

          (print 
            {
              invested-amount: (+ total-payment invested-amount),
              token-amount: amt
            }
          )

          (ok true) 
        )

        (begin 
          (asserts! (> milestone-inside-amt bought-amt) ERR_BIGGER_CURRENT_MILESTONE)
          (map-set listings-ft 
            { 
              maker: asset-owner, 
              contractAddr: ft-asset-contract
            }

            {
              maker: (get maker listing),
              amt: remaining-amt,
              ft-asset-contract: (get ft-asset-contract listing),
              expiry: (get expiry listing),
              price: listing-price,
              payment-asset-contract: (get payment-asset-contract listing),
              milestone: complete-milestone,
              total-collected: listing-total-collected
            }
          )
          
          (map-set asset-m-pool 
            {
              investor: tx-sender, 
              asset: ft-asset-contract
            } 
                          
            {
              token-amt:(+ user-token-amount amt),
              invested-amt: (+ total-payment invested-amount),
              investedMilestone: invested-milestone
            }
          )

          (print 
            {
              invested-amount: (+ total-payment invested-amount),
              token-amount: amt,
              listing-remaining-amt: remaining-amt,
              print-path: u1
            }
          )

          (ok true)
        
        )

      )
    )
    

    

  )
)



(define-public (claim-after-success (ft-asset-contract <ft-trait>) (asset-owner principal))
  (let (
        (user-amt-pool (unwrap! (map-get? asset-m-pool {investor: contract-caller, asset: (contract-of ft-asset-contract)}) ERR_USER_BOUGHT_NOTHING))
        (listing (unwrap! (map-get? listings-ft { maker: asset-owner, contractAddr: (contract-of ft-asset-contract)}) ERR_UNKNOWN_LISTING))
        (listing-milestone (get milestone listing))
        (user-milestone (get investedMilestone user-amt-pool))
        (user tx-sender)
        


  )
    (begin 
      (asserts! (>= listing-milestone user-milestone) ERR_MILESTONE_NOT_COMP)
      (try! (as-contract (transfer-ft ft-asset-contract (get token-amt user-amt-pool) tx-sender user)))
      (map-delete asset-m-pool {
            investor: tx-sender, 
            asset: (contract-of ft-asset-contract)
          })
      (ok true)
    )


  )
  
    
)


(define-public (claim-but-no-success-ft (ft-asset-contract <ft-trait>) (asset-owner principal) (payment-contract <ft-trait>)) 
  (let (
        (user-amt-pool (unwrap! (map-get? asset-m-pool {investor: contract-caller, asset: (contract-of ft-asset-contract)}) ERR_USER_BOUGHT_NOTHING))
        (listing (unwrap! (map-get? listings-ft { maker: asset-owner, contractAddr: (contract-of ft-asset-contract)}) ERR_UNKNOWN_LISTING))
        (listing-milestone (get milestone listing))
        (user-milestone (get investedMilestone user-amt-pool))
        (payment-asset-contract (unwrap! (get payment-asset-contract listing) ERR_NO_PAYMENT_CONTRACT))
        (user tx-sender)
        


  )
    (begin 
      (asserts! (<= burn-block-height (get expiry listing)) ERR_NOT_EXPIRY)
      (asserts! (< listing-milestone user-milestone) ERR_MILESTONE_NOT_COMP)
      (asserts! (is-eq (contract-of payment-contract) payment-asset-contract) ERR_PAYMENT_ASSET_MISMATCH)
      (try! (as-contract (transfer-ft payment-contract (get invested-amt user-amt-pool) tx-sender user)))
      (map-delete asset-m-pool {
            investor: tx-sender, 
            asset: (contract-of ft-asset-contract)
          })
      (ok true)
    )


  )
)

(define-public (claim-but-no-success-stx (ft-asset-contract <ft-trait>) (asset-owner principal)) 
  (let (
        (user-amt-pool (unwrap! (map-get? asset-m-pool {investor: contract-caller, asset: (contract-of ft-asset-contract)}) ERR_USER_BOUGHT_NOTHING))
        (listing (unwrap! (map-get? listings-ft { maker: asset-owner, contractAddr: (contract-of ft-asset-contract)}) ERR_UNKNOWN_LISTING))
        (listing-milestone (get milestone listing))
        (user-milestone (get investedMilestone user-amt-pool))
        (user tx-sender)
  )
    (begin 
      (asserts! (<= burn-block-height (get expiry listing)) ERR_NOT_EXPIRY)
      (asserts! (is-none (get payment-asset-contract listing)) ERR_PAYMENT_ASSET_MISMATCH)
      (asserts! (< listing-milestone user-milestone) ERR_MILESTONE_NOT_COMP)
      (try! (as-contract (stx-transfer? (get invested-amt user-amt-pool) tx-sender user)))

      (map-delete asset-m-pool {
            investor: tx-sender, 
            asset: (contract-of ft-asset-contract)
          })
      (ok true)
    )


  )

)


(define-public (asset-owner-claim-after-milestone-comp (ft-asset-contract <ft-trait>) (owner-asset-contract <call-owner>)) 
 (let (
    (asset-owner (unwrap! (contract-call? owner-asset-contract get-owner) ERR_GETTING_ASSET_OWNER))
    ;; Verify the given listing ID exists
    (listing (unwrap! (map-get? listings-ft { maker: asset-owner, contractAddr: (contract-of ft-asset-contract)}) ERR_UNKNOWN_LISTING))
    
    (milestone (get milestone listing))
    ;; Set the ft's taker to the purchaser (caller of the_function)
    (claim-amt (get total-collected listing))

 ) 
  (asserts! (is-eq (contract-of ft-asset-contract) (contract-of owner-asset-contract)) ERR_FT_AND_CALL_NOT_EQUAL)
  (asserts! (> milestone u0) ERR_MILESTONE_NOT_COMP)
  (asserts! (> claim-amt u0) ERR_CLAIM_AMOUNT_ZERO)
  (try! (as-contract (stx-transfer? claim-amt tx-sender asset-owner)))
  (map-set listings-ft { maker: asset-owner, contractAddr: (contract-of ft-asset-contract)} 
    {
      maker: (get maker listing),
      amt: (get amt listing),
      ft-asset-contract: (get ft-asset-contract listing),
      expiry: (get expiry listing),
      price: (get price listing),
      payment-asset-contract: (get payment-asset-contract listing),
      milestone: (get milestone listing),
      total-collected: u0
    }
  )
  (ok true)

 )
)

  


(define-public (update-protocol-contract
		(contract-type (buff 1))
		(new-contract principal)
	)
	(begin
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


