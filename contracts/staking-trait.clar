(define-trait staking-trait
  (
    (staking (uint uint principal) (response bool uint))
    (unstaking (uint principal) (response bool uint))
  )
)