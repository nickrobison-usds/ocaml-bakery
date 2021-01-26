module L = Libmacaroons

let rt () =
  let m = Utils.unwrap_ok @@ L.Macaroon.create ~location:"http://mybank/" ~key:"his is our super secret key; only we should know it" ~id:"we used our secret key" in
  Alcotest.(check string) "Should have location" "http://mybank/" (L.Macaroon.location m);
  Alcotest.(check string) "Should have identifier" "we used our secret key" (L.Macaroon.identifier m);
  Alcotest.(check string) "Should have correct signature" "ap3k78qHp7k2vd6FGCHVlS_lkuzrQiPU-HXi4QTgECg" (L.Macaroon.signature m)

let v =
  let open Alcotest in
  "readme_tests", [
    test_case "Readme Tests" `Quick rt;
  ]
