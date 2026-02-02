
    ;; title: Token
    ;; version:2
    ;; summary: This is the platform token for my website mock-token which tokenize hotels and real states


    ;; traits
    (impl-trait 'STM6S3AESTK9NAYE3Z7RS00T11ER8JJCDNTKG711.sip-010-trait.sip-010-trait)
    (impl-trait .staking-trait.staking-trait)
    (impl-trait .token-trait.token-trait)
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
    (define-constant err-insufficient-height (err u107))





    ;; data vars
    (define-data-var contract-owner principal tx-sender)
    (define-data-var token-uri (optional (string-utf8 256)) (some u"https://raw.githubusercontent.com/mahanGurung/testcoin/refs/heads/main/testcoin/testcoin.json"))
    (define-data-var contract-callable principal .staking-interface)
    ;;

    ;; data maps
    (define-map admins principal bool)
    (define-map locked-MTA principal {amount: uint, time: uint})
    ;;

    ;; read only functions
    (define-read-only (get-balance (who principal)) (ok (ft-get-balance mock-token who)))
    (define-read-only (get-decimals) (ok u6))
    (define-read-only (get-name) (ok "mock-token"))
    (define-read-only (get-symbol) (ok "MTA"))
    (define-read-only (get-token-uri) (ok (var-get token-uri)))
    (define-read-only (get-total-supply) (ok (ft-get-supply mock-token)))
    (define-read-only (is-admin (user principal)) (default-to false (map-get? admins user)))
    (define-read-only (get-owner) (ok (var-get contract-owner)))

    (define-read-only (get-locked-MTA (who principal)) 
        (let ((lockedTrk (map-get? locked-MTA who)))
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

    ;; User can burn their MTA token
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
            (asserts! (is-eq (var-get contract-callable) contract-caller) err-contract-callable-only)
            (asserts! (> amount u0) err-insufficient-amount)
            (asserts! (> lock-height burn-block-height) err-insufficient-height)
            (asserts! (<= amount (ft-get-balance mock-token sender)) err-insufficient-amount) ;; important: here remove tx-sender and add the sender
            (try! (ft-transfer? mock-token amount sender (as-contract tx-sender))) ;; important: here remove tx-sender and add the sender
            (let ((current-locked (map-get? locked-MTA sender))) ;; important: here remove tx-sender and add the sender
                (map-set locked-MTA sender { amount: (+ (default-to u0 (get amount current-locked)) amount), time:lock-height })) ;; important: here remove tx-sender and add the sender //
            
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


    (define-public (unstaking (amount uint) (sender principal))
    (begin
        (asserts! (is-eq (var-get contract-callable) contract-caller) err-contract-callable-only)
        (asserts! (> amount u0) err-insufficient-amount)
        
        (let ((user-locked (map-get? locked-MTA sender)))
        (let ((locked-amount (default-to u0 (get amount user-locked)))
                (locked-time (default-to u0 (get time user-locked))))
            (asserts! (<= amount locked-amount) err-insufficient-amount)
            (asserts! (> burn-block-height locked-time) err-insufficient-height)

            (try! (as-contract (ft-transfer? mock-token amount (as-contract tx-sender) sender)))
            (map-set locked-MTA sender { amount: (- locked-amount amount), time: locked-time }) 
            (print { event-type: "UnlockTrk", amount: amount, user: sender })
            (ok true)
        )
        )
    )
    )

    (mint u100000000 tx-sender)
    ;; (mint u100000000 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG)