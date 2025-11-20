(use-trait ft-trait 'STM6S3AESTK9NAYE3Z7RS00T11ER8JJCDNTKG711.sip-010-trait.sip-010-trait)
(use-trait call-owner .token-trait.token-trait)


(define-public (forward-get-balance (contract <ft-trait>))
  (begin
    (ok (contract-of contract)))) ;; returns the principal of the contract implementing <token-a-trait>

(define-read-only (get-trait (trait-contract <call-owner>)) 
  trait-contract
)

(define-private (get-token-owner (asset <call-owner>))
  (let ((asset-owner (unwrap! (contract-call? asset get-owner) (err u100)))) 
       (asserts! (is-eq tx-sender asset-owner) (err u010))
       (ok true)
  )
)