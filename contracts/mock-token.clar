
;; title: Token
;; version:2
;; summary: This is the platform token for my website mock-token which tokenize hotels and real states


;; traits
(impl-trait 'STM6S3AESTK9NAYE3Z7RS00T11ER8JJCDNTKG711.sip-010-trait.sip-010-trait)
(impl-trait .staking-trait.staking-trait)
;;

;; token definitions
(define-fungible-token mock-token u1000000000)
;;

;; constants
(define-constant err-insufficient-amount (err u100))
(define-constant not-token-owner (err u103))
(define-constant err-not-authorized (err u104))
(define-constant err-owner-only (err u105))
(define-constant err-contract-callable-only (err u106))




;; data vars
(define-data-var contract-owner principal tx-sender)
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://raw.githubusercontent.com/mahanGurung/testcoin/refs/heads/main/testcoin/testcoin.json"))
(define-data-var contract-callable principal .staking-interface)
;;

;; data maps
(define-map admins principal bool)
(define-map locked-GFD principal {amount: uint, time: uint})
;;

;; read only functions
(define-read-only (get-balance (who principal)) (ok (ft-get-balance mock-token who)))
(define-read-only (get-decimals) (ok u6))
(define-read-only (get-name) (ok "mock-token"))
(define-read-only (get-symbol) (ok "GFD"))
(define-read-only (get-token-uri) (ok (var-get token-uri)))
(define-read-only (get-total-supply) (ok (ft-get-supply mock-token)))
(define-read-only (is-admin (user principal)) (default-to false (map-get? admins user)))
(define-read-only (get-locked-GFD (who principal)) 
    (let ((lockedTrk (map-get? locked-GFD who)))
        (ok (default-to u0 (get amount lockedTrk)))
    )
)
;;


;; public functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin 
        (asserts! (is-eq tx-sender sender) not-token-owner)
        (asserts! (> amount u0) err-insufficient-amount)
        (try! (ft-transfer? mock-token amount sender recipient))
        (print { event-type: "Transfer", amount: amount, sender: sender, recipient: recipient })
        (match memo to-print (print to-print) 0x)
        (ok true)
    )
)

;; Function to mint the token 
(define-public (mint (amount uint) (recipient principal))
    (begin 
        (asserts! (or (is-eq tx-sender (var-get contract-owner)) (default-to false (map-get? admins tx-sender))) err-not-authorized)
        (asserts! (> amount u0) err-insufficient-amount)
        (try! (ft-mint? mock-token amount recipient))
        (print { event-type: "Mint", amount: amount, recipient: recipient})
        (ok true)
    )
)

;; User can burn their GFD token
(define-public (burn (amount uint))
    (begin 
        (asserts! (> amount u0) err-insufficient-amount)
        (try! (ft-burn? mock-token amount tx-sender))
        (print { event-type: "burn", amount: amount, recipient: tx-sender})
        (ok true)
    )
)

;; Owner can transfer ownership to other 
(define-public (transfer-ownership (new-owner principal))
    (begin 
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

;; contract owner can add admin
(define-public (add-admin (admin principal))
    (begin 
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (map-set admins admin true)
        (ok true)
    )
)

(define-public (remove-admin (admin principal))
    (begin 
        (asserts! (is-eq tx-sender (var-get contract-owner)) err-owner-only)
        (map-delete admins admin)
        (ok true))
)

(define-public (set-token-uri (value (string-utf8 256)))
    (if 
        (is-eq tx-sender (var-get contract-owner)) 
            (ok (var-set token-uri (some value))) 
        err-owner-only
    )
)



(define-public (staking (amount uint) (lock-height uint) (sender principal)) ;; important: add parameter sender
    (begin 
        (asserts! (is-eq (var-get contract-callable) tx-sender) err-contract-callable-only)
        (asserts! (> amount u0) err-insufficient-amount)
        (asserts! (> lock-height u1000) err-insufficient-amount)
        (asserts! (<= amount (ft-get-balance mock-token sender)) err-insufficient-amount) ;; important: here remove tx-sender and add the sender
        (try! (ft-transfer? mock-token amount sender (as-contract sender))) ;; important: here remove tx-sender and add the sender
        (let ((current-locked (map-get? locked-GFD sender))) ;; important: here remove tx-sender and add the sender
            (map-set locked-GFD sender { amount: (+ (default-to u0 (get amount current-locked)) amount), time:lock-height })) ;; important: here remove tx-sender and add the sender
        
        (print { event-type: "LockTrk", amount: amount, user: sender }) ;; important: here remove tx-sender and add the sender
        (ok true)
    )
)


(define-public (set-contract-callable (contract-principle  principal))
    (begin 
        (asserts! (is-eq (var-get contract-owner) tx-sender) err-owner-only)
        (var-set contract-callable contract-principle)
        (ok true)
    )
)

;; (define-public (unlock-GFD (amount uint))
;;     (begin 
;;         (asserts! (> amount u0) err-insufficient-amount)
;;         (let ((user-locked (map-get? locked-GFD tx-sender)))
;;             (asserts! (<= amount (default-to u0 (get amount user-locked))) err-insufficient-amount)
;;             (try! (as-contract (ft-transfer? mock-token amount (as-contract tx-sender) tx-sender)))
;;             (map-set locked-GFD tx-sender {  amount:(- (get amount user-locked) amount), time: (get time user-locked)}) 
;;             (print { event-type: "UnlockTrk", amount: amount, user: tx-sender })
;;             (ok true)
;;         )
;;     )
;; )

(define-public (unstaking (amount uint) (sender principal))
  (begin
    (asserts! (is-eq (var-get contract-callable) tx-sender) err-contract-callable-only)
    (asserts! (> amount u0) err-insufficient-amount)
    (let ((user-locked (map-get? locked-GFD sender)))
      (let ((locked-amount (default-to u0 (get amount user-locked)))
            (locked-time (default-to u0 (get time user-locked))))
        (asserts! (<= amount locked-amount) err-insufficient-amount)
        (try! (as-contract (ft-transfer? mock-token amount (as-contract sender) sender)))
        (map-set locked-GFD sender { amount: (- locked-amount amount), time: locked-time }) 
        (print { event-type: "UnlockTrk", amount: amount, user: sender })
        (ok true)
      )
    )
  )
)



(mint u10000000 (var-get contract-owner))
(mint u1000000 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)
(mint u1000000 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)
(mint u1000000 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC)





