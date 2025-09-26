(use-trait staking-ft .staking-trait.staking-trait)

(define-read-only (is-whitelisted (contract principal))
  ;; ask marketplace if contract is whitelisted
  (contract-call? .marketplace is-whitelisted contract)
)

(define-public (staking (staking-contract <staking-ft>) (amount uint) (time uint) )
  (begin
    (is-whitelisted (contract-of staking-contract))

    ;; dynamic contract call
    (try! (contract-call? staking-contract staking amount time tx-sender))
     (print {
        stacking-contract: staking-contract,
        staker: tx-sender,
        block-time: time,
        amount: amount
        })
    (ok true)

  )
)



(define-public (unstaking (staking-contract <staking-ft>) (amount uint))
  (begin
    ;; (is-whitelisted (contract-of staking-contract))
    

    ;; dynamic contract call
    (try! (contract-call? staking-contract unstaking amount tx-sender))
    (print {
        stacking-contract: staking-contract,
        unstaker: tx-sender,
        amount: amount
        })
    (ok true)
  )
)

;; ---- Constants / Errors ----
(define-constant ERR-NOT-WHITELISTED (err u100)) ;; use your preferred error codes



