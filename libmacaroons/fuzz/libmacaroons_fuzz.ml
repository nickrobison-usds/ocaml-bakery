open Crowbar

let max_len = bytes_fixed 10

let non_zero =
  map [bytes] (fun s ->
      match (String.length s) with
      | 0 | 1 -> (bad_test ())
      | _ -> s)

let b64 =
  map [non_zero] (fun s ->
      match (Base64.encode ~pad:false ~alphabet:Base64.uri_safe_alphabet s) with
      | Ok b -> b
      | Error _ -> (bad_test ()))

let to_from orig =
  let encoded = Libmacaroons.Base64.decode orig in
  Libmacaroons.Base64.encode encoded



let () =
  add_test ~name:"base64" [b64] @@ fun y -> check_eq ~pp:pp_string (to_from y) y
