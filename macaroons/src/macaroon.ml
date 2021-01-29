
type t = {
  id: string;
  location: string;
  caveats: Caveat.t list;
  signature: Cstruct.t;
}

type macaroon_format = | V1 | V2 | V2J


(*Serializer stuff*)

(** Encode package length. Stolen from: https://github.com/nojb/ocaml-macaroons/blob/712150ec551e0d3b0c8c4b90ee05fed41fe501bc/lib/macaroons.ml#L125*)
let w_int n =
  let p s o =
    let digits = "0123456789abcdef" in
    let c i =
      let x = ((n lsr (4*(3-i))) land 0xF) in
      digits.[x]
    in
    Bytes.set s (o + 0) (c 0);
    Bytes.set s (0 + 1) (c 1);
    Bytes.set s (0 + 2) (c 2);
    Bytes.set s (0 + 3) (c 3)
  in
  p

let get_buffer_size t =
  let id_len = 6 + String.length "identifier" + String.length t.id in
  let loc_len = 6 + String.length "location" + String.length t.location in
  id_len + loc_len

let write_packet t k v =
  let len = 6 + String.length k + Bytes.length v in
  let header = Bytes.create 4 in
  let v' = w_int len in
  v' header 0;
  let open Faraday in
  write_bytes t header;
  write_string t k;
  write_char t ' ';
  write_bytes t v;
  write_char t '\n'

let write_caveats t caveats =
  (* I think this can probably be optimized a lot better, seems like a ton of allocations*)
  List.iter (fun c -> write_packet t "cid" (Caveat.to_bytes c)) caveats


let serialize m =
  let open Faraday in
  let t = create (get_buffer_size m) in
  write_packet t "location" (Bytes.of_string m.location);
  write_packet t "identifier" (Bytes.of_string m.id);
  write_caveats t m.caveats;
  write_packet t "signature" (Cstruct.to_bytes m.signature);
  serialize_to_string t

let macaroons_magic_key = Cstruct.of_string "macaroons-key-generator"

let b64_encode = Base64.encode_exn ?alphabet:(Some Base64.uri_safe_alphabet) ~pad:false

let hmac key msg =
  Nocrypto.Hash.SHA256.hmac ~key msg

(* Derives a new root key from [macaroons_magic_key] *)
let derive_key = hmac macaroons_magic_key

let create ~id ~location key =
  let key' = Cstruct.of_string key
             |> derive_key in
  {
    id;
    location;
    caveats = [];
    signature = (hmac key' (Cstruct.of_string id));
  }

let identifier t =
  t.id

let location t =
  t.location

let signature_raw t =
  t.signature

let signature {signature; _} =
  let h = Hex.of_cstruct signature in
  match h with
  | `Hex s -> s

let num_caveats t = List.length t.caveats

let add_first_party_caveat t cav =
  let module H = Nocrypto.Hash.SHA256 in
  let b = Caveat.to_cstruct cav in
  let signature = hmac t.signature b in
  {t with caveats = t.caveats @ [cav]; signature}


let serialize t format =
  match format with
  | V1 -> serialize t |> b64_encode
  | _ -> raise (Invalid_argument "Cannot serialize to this, yet")
