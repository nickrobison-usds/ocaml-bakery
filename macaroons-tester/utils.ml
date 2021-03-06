module Make(C: Sig.Caveat)(M: Sig.Macaroon with type c = C.t)(V: Sig.Verifier with type m = M.t) = struct

  let return_code_to_message = function
    | `Success -> "Success"
    | `Invalid -> "Invalid Macaroon"
    | `Not_Authorized -> "Macaroon not authorized"
    | `Oom -> "Out of memory"
    | `E e -> e
(*
  (** Unwrap a Result and assert that it's Ok. Otherwise, fail with return code*)
  let unwrap_ok = function
    | Ok r -> r
    | Error e -> Alcotest.failf "Unexpected failure: %s" (return_code_to_message e)
   *)

  (** Alcotest check function that verifies a Polymorphic variant matches what's expected*)
  let expect_variant msg l r =
    Alcotest.(check string) msg (return_code_to_message l) (return_code_to_message r)

  (** Fail a test with a nice error message from the resulting return code*)
  let fail_return_code e =
    Alcotest.failf "Failed with return code: %s" (return_code_to_message e)

  (** Helper function for adding a caveat to a verifier*)
  let add_caveat v caveat =
    match V.satisfy_exact v caveat with
    | Ok v -> v
    | Error _e -> Alcotest.failf "Could not add caveat: %s" "error"


  (** Assert that the result of a macaroon verification is unauthorized*)
  let assert_unauthorized = function
    | Ok _ -> Alcotest.fail "Should be unauthorized"
    | Error e -> match e with
      | `Not_authorized -> ()
      | `Invalid -> Alcotest.fail "Should be unauthorized, but was invalid instead"

  (** Helper function to deserialize a macaroon and verify it with the default root key*)
  let verify_macaroon v str k =
    let deser = M.deserialize str in
    match deser with
    | Ok m -> V.verify v m k
    | Error e -> Alcotest.failf "Cannot verify: %s" e

  (** Assert that the result of a macaroon verification is authorized*)
  let assert_authorized = function
    | Ok _ -> ()
    | Error _ -> Alcotest.fail "Should be authorized"

  (** Run libmacaroons verification test*)
  let verifier_test m caveats fn =
    let v = List.fold_left (fun v c -> add_caveat v c) (V.create ()) caveats in
    fn (verify_macaroon v m "this is the key")

  (** Unwrap a Result and assert that it's Ok. Otherwise, fail with return code*)
  let unwrap_ok = function
    | Ok r -> r
    | Error e -> Alcotest.failf "Unexpected failure: %s" e
(*
  (** Run libmacaroons verification test*)
  let verifier_test m caveats fn =
    let v = List.fold_left (fun v c -> add_caveat v c) (V.create ()) caveats in
    fn (verify_macaroon v m "this is the key")
    **)
end
