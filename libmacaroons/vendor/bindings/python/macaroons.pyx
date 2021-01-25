# Copyright (c) 2014, Robert Escriva
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of this project nor the names of its contributors may
#       be used to endorse or promote products derived from this software
#       without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import binascii
import sys

cdef extern from "stdlib.h":

    void* malloc(size_t size)
    void free(void* ptr)


cdef extern from "macaroons.h":

    DEF MACAROON_MAX_STRLEN  = 32768
    DEF MACAROON_MAX_CAVEATS = 65536

    cdef struct macaroon
    cdef struct macaroon_verifier

    cdef enum macaroon_returncode:
        MACAROON_SUCCESS          = 2048
        MACAROON_OUT_OF_MEMORY    = 2049
        MACAROON_HASH_FAILED      = 2050
        MACAROON_INVALID          = 2051
        MACAROON_TOO_MANY_CAVEATS = 2052
        MACAROON_CYCLE            = 2053
        MACAROON_BUF_TOO_SMALL    = 2054
        MACAROON_NOT_AUTHORIZED   = 2055
        MACAROON_NO_JSON_SUPPORT  = 2056

    macaroon* macaroon_create(unsigned char* location, size_t location_sz, unsigned char* key, size_t key_sz, unsigned char* id, size_t id_sz, macaroon_returncode* err)
    void macaroon_destroy(macaroon* M)
    int macaroon_validate(const macaroon* M)
    macaroon* macaroon_add_first_party_caveat(const macaroon* M, const unsigned char* predicate, size_t predicate_sz, macaroon_returncode* err)
    macaroon* macaroon_add_third_party_caveat(const macaroon* M, const unsigned char* location, size_t location_sz, const unsigned char* key, size_t key_sz, const unsigned char* id, size_t id_sz, macaroon_returncode* err)
    unsigned macaroon_num_third_party_caveats(const macaroon* M)
    int macaroon_third_party_caveat(const macaroon* M, unsigned which, const unsigned char** location, size_t* location_sz, const unsigned char** identifier, size_t* identifier_sz)
    macaroon* macaroon_prepare_for_request(const macaroon* M, const macaroon* D, macaroon_returncode* err)
    macaroon_verifier* macaroon_verifier_create()
    void macaroon_verifier_destroy(macaroon_verifier* V)
    int macaroon_verifier_satisfy_exact(macaroon_verifier* V, const unsigned char* predicate, size_t predicate_sz, macaroon_returncode* err)
    int macaroon_verifier_satisfy_general(macaroon_verifier* V, int (*general_check)(void* f, const unsigned char* pred, size_t pred_sz), void* f, macaroon_returncode* err)
    int macaroon_verify(const macaroon_verifier* V, const macaroon* M, const unsigned char* key, size_t key_sz, macaroon** MS, size_t MS_sz, macaroon_returncode* err)
    void macaroon_location(const macaroon* M, const unsigned char** location, size_t* location_sz)
    void macaroon_identifier(const macaroon* M, const unsigned char** identifier, size_t* identifier_sz)
    void macaroon_signature(const macaroon* M, const unsigned char** signature, size_t* signature_sz)
    size_t macaroon_inspect_size_hint(macaroon* M)
    int macaroon_inspect(macaroon* M, char* data, size_t data_sz, macaroon_returncode* err)
    macaroon* macaroon_copy(macaroon* M, macaroon_returncode* err)
    int macaroon_cmp(macaroon* M, macaroon* N)

    cdef enum macaroon_format:
        MACAROON_V1
        MACAROON_V2
        MACAROON_V2J
    cdef macaroon_format MACAROON_LATEST
    cdef macaroon_format MACAROON_LATEST_JSON
    size_t macaroon_serialize_size_hint(const macaroon* M, macaroon_format f)
    size_t macaroon_serialize(const macaroon* M, macaroon_format f,
                              char* buf, size_t buf_sz,
                              macaroon_returncode* err)
    macaroon* macaroon_deserialize(unsigned char* data, size_t data_sz, macaroon_returncode* err)


SUGGESTED_SECRET_LENGTH = 32


class MacaroonError(Exception): pass
class Unauthorized(Exception): pass


cdef bytes tobytes(s):
    if type(s) in (unicode, str) and sys.version_info.major >= 3:
        return s.encode('utf8')
    elif type(s) is bytes:
        return s
    else:
        raise TypeError("a bytes/str-like object is required, not '%s'" % s.__class__.__name__)


cdef raise_error(macaroon_returncode err):
    if err == MACAROON_OUT_OF_MEMORY:
        raise MemoryError
    X = {MACAROON_HASH_FAILED:      'HMAC function failed',
         MACAROON_INVALID:          'macaroon invalid',
         MACAROON_TOO_MANY_CAVEATS: 'too many caveats',
         MACAROON_CYCLE:            'discharge caveats form a cycle',
         MACAROON_BUF_TOO_SMALL:    'buffer too small',
         MACAROON_NOT_AUTHORIZED:   'not authorized',
         MACAROON_NO_JSON_SUPPORT:  'JSON macaroons not supported'}
    raise MacaroonError(X.get(err, 'operation failed unexpectedly'))


cdef class Macaroon:
    cdef macaroon* _M

    def __cinit__(self):
        self._M = NULL

    def __dealloc__(self):
        if self._M != NULL:
            macaroon_destroy(self._M)
            self._M = NULL

    def validate(self):
        return macaroon_validate(self._M) == 0

    @property
    def location(self):
        cdef const unsigned char* location = NULL
        cdef size_t location_sz = 0
        self.assert_not_null()
        macaroon_location(self._M, &location, &location_sz)
        return location[:location_sz]

    @property
    def identifier(self):
        cdef const unsigned char* identifier = NULL
        cdef size_t identifier_sz = 0
        self.assert_not_null()
        macaroon_identifier(self._M, &identifier, &identifier_sz)
        return identifier[:identifier_sz]

    @property
    def signature(self):
        cdef const unsigned char* signature = NULL
        cdef size_t signature_sz = 0
        self.assert_not_null()
        macaroon_signature(self._M, &signature, &signature_sz)
        return binascii.hexlify(signature[:signature_sz])

    def copy(self):
        self.assert_not_null()
        cdef macaroon_returncode err
        cdef Macaroon M = Macaroon()
        M._M = macaroon_copy(self._M, &err)
        if M._M == NULL:
            raise_error(err)
        return M

    def serialize(self, format='latest'):
        cdef macaroon_format f = self.version(format)
        cdef char* data = NULL
        cdef size_t data_sz = 0
        cdef macaroon_returncode err
        self.assert_not_null()
        try:
            data_sz = macaroon_serialize_size_hint(self._M, f)
            data = <char*>malloc(sizeof(unsigned char) * data_sz)
            if data == NULL:
                raise MemoryError
            data_sz = macaroon_serialize(self._M, f, data, data_sz, &err)
            if data_sz == 0:
                raise_error(err)
            if self.is_json(format):
                return bytes(data[:data_sz]).decode('utf8')
            else:
                return bytes(data[:data_sz])
        finally:
            if data != NULL:
                free(data)

    def inspect(self):
        cdef char* data = NULL
        cdef size_t data_sz = 0
        cdef macaroon_returncode err
        self.assert_not_null()
        try:
            data_sz = macaroon_inspect_size_hint(self._M)
            data = <char*>malloc(sizeof(unsigned char) * data_sz)
            if data == NULL:
                raise MemoryError
            if macaroon_inspect(self._M, data, data_sz, &err) < 0:
                raise_error(err)
            return bytes(data)
        finally:
            if data != NULL:
                free(data)

    def is_same(self, Macaroon M):
        self.assert_not_null()
        M.assert_not_null()
        return macaroon_cmp(self._M, M._M) == 0

    def third_party_caveats(self):
        self.assert_not_null()
        cdef const unsigned char* location = NULL
        cdef size_t location_sz = 0
        cdef const unsigned char* identifier = NULL
        cdef size_t identifier_sz = 0
        cdef unsigned num = macaroon_num_third_party_caveats(self._M)
        ids = []
        for i in range(num):
            if macaroon_third_party_caveat(self._M, i,
                    &location, &location_sz, &identifier, &identifier_sz) < 0:
                raise_error(MACAROON_INVALID)
            ids.append((location[:location_sz], identifier[:identifier_sz]))
        return ids

    def prepare_for_request(self, Macaroon D):
        cdef macaroon_returncode err
        cdef Macaroon DP = Macaroon()
        self.assert_not_null()
        D.assert_not_null()
        DP._M = macaroon_prepare_for_request(self._M, D._M, &err)
        if DP._M == NULL:
            raise_error(err)
        return DP

    def add_first_party_caveat(self, predicate):
        self.assert_not_null()
        predicate = tobytes(predicate)
        cdef macarr
        cdef macaroon_returncode err
        cdef Macaroon M = Macaroon()
        M._M = macaroon_add_first_party_caveat(self._M,
                predicate, len(predicate), &err)
        if M._M == NULL:
            raise_error(err)
        return M

    def add_third_party_caveat(self, _location, _key, _key_id):
        _location = tobytes(_location)
        _key = tobytes(_key)
        _key_id = tobytes(_key_id)
        cdef unsigned char* location = _location
        cdef size_t location_sz = len(_location)
        cdef unsigned char* key = _key
        cdef size_t key_sz = len(_key)
        cdef unsigned char* key_id = _key_id
        cdef size_t key_id_sz = len(_key_id)
        cdef macaroon_returncode err
        cdef Macaroon M = Macaroon()
        self.assert_not_null()
        M._M = macaroon_add_third_party_caveat(self._M,
                location, location_sz, key, key_sz, key_id, key_id_sz, &err)
        if M._M == NULL:
            raise_error(err)
        return M

    cdef assert_not_null(self):
        if self._M == NULL:
            raise ValueError("macaroon not initialized")

    cdef macaroon_format version(self, v):
        cdef macaroon_format f = {'latest': MACAROON_LATEST,
                                  'binary': MACAROON_LATEST,
                                  'json': MACAROON_LATEST_JSON,
                                  '2j': MACAROON_V2J,
                                  2: MACAROON_V2,
                                  '2': MACAROON_V2,
                                  1: MACAROON_V1,
                                  '1': MACAROON_V1}[v]
        return f

    cdef is_json(self, v):
        return {'latest': False,
                'binary': False,
                'json': True,
                '2j': True,
                2: False,
                '2': False,
                1: False,
                '1': False}[v]


cdef int general_cb(void* f, const unsigned char* pred, size_t pred_sz):
    try:
        if (<object>f)(pred[:pred_sz]):
            return 0
    except: pass
    return -1


cdef class Verifier:
    cdef macaroon_verifier* _V
    cdef list _funcs

    def __cinit__(self):
        self._V = macaroon_verifier_create()
        if self._V == NULL:
            raise MemoryError
        self._funcs = []

    def __dealloc__(self):
        if self._V != NULL:
            macaroon_verifier_destroy(self._V)
            self._V = NULL

    def satisfy_exact(self, pred):
        cdef macaroon_returncode err
        pred = tobytes(pred)
        if macaroon_verifier_satisfy_exact(self._V, pred, len(pred), &err) < 0:
            raise_error(err)

    def satisfy_general(self, func):
        cdef macaroon_returncode err
        if macaroon_verifier_satisfy_general(self._V, general_cb, <void*>func, &err) < 0:
            raise_error(err)
        self._funcs.append(func)

    def verify(self, Macaroon M, key, MS=None):
        key = tobytes(key)
        if self.verify_unsafe(M, key, MS):
            return True
        else:
            raise Unauthorized("macaroon not authorized")

    def verify_unsafe(self, Macaroon M, key, MS=None):
        key = tobytes(key)
        cdef macaroon_returncode err
        cdef macaroon** discharges = NULL
        cdef Macaroon tmp
        if M is None:
            return False
        try:
            M.assert_not_null()
            MS = MS or []
            discharges = <macaroon**>malloc(sizeof(macaroon*) * len(MS))
            for i, D in enumerate(MS):
                tmp = D
                tmp.assert_not_null()
                discharges[i] = tmp._M
            rc = macaroon_verify(self._V, M._M, key, len(key), discharges, len(MS), &err)
            if rc == 0:
                return True
            elif err == MACAROON_NOT_AUTHORIZED:
                return False
            else:
                raise_error(err)
        finally:
            if discharges:
                free(discharges)


def create(_location, _key, _key_id):
    _location = tobytes(_location)
    _key = tobytes(_key)
    _key_id = tobytes(_key_id)
    cdef unsigned char* location = _location
    cdef size_t location_sz = len(_location)
    cdef unsigned char* key = _key
    cdef size_t key_sz = len(_key)
    cdef unsigned char* key_id = _key_id
    cdef size_t key_id_sz = len(_key_id)
    cdef macaroon_returncode err
    cdef Macaroon M = Macaroon()
    M._M = macaroon_create(location, location_sz,
                           key, key_sz, key_id, key_id_sz, &err)
    if M._M == NULL:
        raise_error(err)
    return M


def deserialize(m):
    cdef Macaroon M = Macaroon()
    cdef macaroon_returncode err
    m = tobytes(m)
    M._M = macaroon_deserialize(m, len(m), &err)
    if M._M == NULL:
        raise_error(err)
    return M
