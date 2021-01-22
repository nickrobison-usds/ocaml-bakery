module T = Libmacaroons_types.M

type t

val create: unit -> t

val verify: t -> Macaroon.t -> string -> (unit, T.ReturnCode.t) result


val satisfy_exact: t -> string -> (unit, T.ReturnCode.t) result
