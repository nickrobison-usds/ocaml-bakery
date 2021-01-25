open Alcotest

let () =
  run "Unit tests" [
    "base64", [
      test_case "Base64" `Quick Test_b64.v
    ];
    Test_verifier_v1.v;
    Test_verifier_v2.v;
    Test_root_v1.v;
    Test_root_v2.v;
    Test_serialize.v;
  ]
