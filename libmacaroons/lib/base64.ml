open Ctypes
module M = Libmacaroons_ffi.M

let encode arry =
  let input_length  = CArray.length arry in
  let ret_buffer = allocate_n char ~count:(input_length * 2) in
  let ret_sz = Unsigned.Size_t.of_int (input_length * 2) in
  let res = M.Base64.b64_ntop (CArray.start arry) (Unsigned.Size_t.of_int input_length) ret_buffer ret_sz in
  string_from_ptr ret_buffer ~length:res

let decode str =
  let ret_sz = Unsigned.Size_t.of_int (String.length str) in
  let ret_buffer = allocate_n uchar ~count:(String.length str) in
  let res = M.Base64.b64_pton str ret_buffer ret_sz in
  CArray.from_ptr ret_buffer res
