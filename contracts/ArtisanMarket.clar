;; ArtisanMarket - Decentralized marketplace for handcrafted goods
(define-map artisan-products uint {
  creator: principal,
  product-name: (string-utf8 64),
  craft-description: (string-utf8 256),
  creation-date: uint,
  workshop-location: (string-utf8 64),
  authenticity-verified: bool
})

(define-map creator-inventory principal (list 100 uint))
(define-map verified-authenticators principal bool)
(define-data-var product-id-counter uint u0)

;; Error codes
(define-constant err-not-creator (err u400))
(define-constant err-not-authenticator (err u401))
(define-constant err-product-not-found (err u402))
(define-constant err-access-denied (err u403))
(define-constant err-inventory-full (err u404))
(define-constant err-invalid-authenticator-address (err u405))
(define-constant err-invalid-product-name (err u406))
(define-constant err-invalid-description (err u407))
(define-constant err-invalid-creation-date (err u408))
(define-constant err-invalid-workshop-location (err u409))
(define-constant err-invalid-product-id (err u410))

;; Marketplace administrator
(define-constant marketplace-admin tx-sender)

;; Register craft authenticator
(define-public (register-craft-authenticator (authenticator principal))
  (begin
    ;; Check if sender is marketplace admin
    (asserts! (is-eq tx-sender marketplace-admin) err-access-denied)
    
    ;; Validate authenticator principal
    (asserts! (not (is-eq authenticator 'SP000000000000000000002Q6VF78)) err-invalid-authenticator-address)
    
    ;; Add authenticator to registry
    (ok (map-set verified-authenticators authenticator true))
  )
)

;; List artisan product
(define-public (list-artisan-product 
  (product-name (string-utf8 64)) 
  (craft-description (string-utf8 256)) 
  (creation-date uint) 
  (workshop-location (string-utf8 64)))
  (let
    ((product-id (var-get product-id-counter))
     (creator tx-sender)
     (current-inventory (default-to (list) (map-get? creator-inventory creator))))
    
    ;; Validate inputs
    (asserts! (> (len product-name) u0) err-invalid-product-name)
    (asserts! (> (len craft-description) u0) err-invalid-description)
    (asserts! (> creation-date u0) err-invalid-creation-date)
    (asserts! (> (len workshop-location) u0) err-invalid-workshop-location)
    
    ;; Check inventory limit
    (asserts! (< (len current-inventory) u100) err-inventory-full)
    
    ;; Store product information
    (map-set artisan-products product-id {
      creator: creator,
      product-name: product-name,
      craft-description: craft-description,
      creation-date: creation-date,
      workshop-location: workshop-location,
      authenticity-verified: false
    })
    
    ;; Update creator's inventory
    (let 
      ((updated-inventory (unwrap-panic (as-max-len? (concat (list product-id) current-inventory) u100))))
      (map-set creator-inventory creator updated-inventory)
    )
    
    ;; Increment product ID counter
    (var-set product-id-counter (+ product-id u1))
    
    (ok product-id)))

;; Verify product authenticity
(define-public (verify-product-authenticity (product-id uint))
  (begin
    ;; Validate product ID
    (asserts! (< product-id (var-get product-id-counter)) err-invalid-product-id)
    
    (let
      ((product (unwrap! (map-get? artisan-products product-id) err-product-not-found)))
      
      ;; Check if sender is verified authenticator
      (asserts! (default-to false (map-get? verified-authenticators tx-sender)) err-not-authenticator)
      
      ;; Update product authenticity status
      (ok (map-set artisan-products product-id (merge product {authenticity-verified: true})))
    )
  )
)

;; Get product details
(define-read-only (get-product-details (product-id uint))
  (map-get? artisan-products product-id))

;; Get creator's inventory
(define-read-only (get-creator-inventory (creator principal))
  (default-to (list) (map-get? creator-inventory creator)))

;; Check authenticator status
(define-read-only (is-verified-authenticator (address principal))
  (default-to false (map-get? verified-authenticators address)))
