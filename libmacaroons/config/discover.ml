module C = Configurator.V1

let bsd_libutil = {|
#include <bsd/libutil.h>

int main() {
  uint8_t *buffer = malloc(10);
  arc4random_buf(buffer, 10);
  return 0;
}
|}


let libutil = {|
#include <libutil.h>

int main() {
  uint8_t *buffer = malloc(10);
  arc4random_buf(buffer, 10);
  return 0;
}
|}

let macos_libutil = {|
#include <stdlib.h>
#include <util.h>

int main() {
  uint8_t *buffer = malloc(10);
  arc4random_buf(buffer, 10);
  return 0;
}
|}

let define_constants c =
  let bsd_libutil = C.c_test c bsd_libutil ~link_flags:["-lbsd"] in
  let libutil = C.c_test c libutil in
  let macos_libutil = C.c_test c macos_libutil in
  let open C.C_define.Value in
  let configs = match bsd_libutil, libutil, macos_libutil with
  | true, _, _ -> ["HAVE_BSD_LIBUTIL_H", Switch true]
  | _, true, _ -> ["HAVE_LIBUTIL_H", Switch true]
  | _, _, true -> ["HAVE_OSX_LIBUTIL_H", Switch true]
  | false, false, false -> raise (Invalid_argument "Cannot find libutil implementation") in
  C.C_define.gen_header_file c ~fname:"config.h" configs

let arch_flags c =
  let arch = C.ocaml_config_var_exn c "architecture" in
  let flags = match arch with
  | "arm64" -> []
  | _ -> ["-msse4.1"]
  in
  String.concat " " flags


let ocamlopt_lines c =
  let cflags =
    try C.ocaml_config_var_exn c "ocamlopt_cflags"
    with _ -> "-O3 -fno-strict-aliasing -fwrapv" in
  let cflags = cflags ^ (arch_flags c) in
  C.Flags.extract_blank_separated_words cflags

let link_flags c =
  let system = C.ocaml_config_var_exn c "system" in
  let libs = match system with
    | "linux" -> ["bsd"]
    | _ -> [] in
  List.map (fun l -> "-l" ^ l) libs

let () =
  let cstubs = ref "" in
  let args = Arg.["-cstubs", Set_string cstubs, "cstubs loc"] in
  C.main ~args ~name:"libmacaroons" (fun c ->
      let cstubs_cflags = Printf.sprintf "-I%s" (Filename.dirname !cstubs) in
      let lines = ocamlopt_lines c @ ["-DHAVE_CONFIG_H"] in
      let link_flags = link_flags c in
      C.Flags.write_lines "cflags" lines;
      C.Flags.write_lines "ctypes-cflags" [cstubs_cflags];
      C.Flags.write_sexp "c_library_flags.sexp" link_flags;
      C.Flags.write_lines "c_library_flags" link_flags;
      define_constants c;
    )
