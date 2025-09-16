;; title: marketplace-admin

;; description: test upgardable contract logic admin

;; constants
;;
(define-constant ERR_UNAUTHORIZED (err u400))

(define-constant admin-role 0x00)
(define-constant admin tx-sender)

;; public functions
;;
(define-public (update-contract
        (contract-type (buff 1))
		(new-contract principal)
    ) 
    (begin
        (asserts! (is-eq admin tx-sender) ERR_UNAUTHORIZED)
        (try! (contract-call? .marketplace update-protocol-contract contract-type new-contract))
        (ok true)
    )
)