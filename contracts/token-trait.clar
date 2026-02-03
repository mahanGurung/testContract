(define-trait token-trait
  (
    (get-owner () (response principal uint))
    (staking (uint uint principal) (response bool uint))
    (unstaking (uint principal) (response bool uint))
  )
)

