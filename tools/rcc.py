#!/usr/bin/env python3
"""Le um bundle de recursos Qt (.rcc) sem depender do Qt instalado.

Formato (versao 1..3), tudo big-endian:

  cabecalho: "qres" | versao u32 | offset da arvore u32 | offset dos dados u32
             | offset dos nomes u32 | [v3] flags gerais u32

  no da arvore (22 bytes na v2+, 14 na v1):
      offset do nome u32 | flags u16
      diretorio (flags & 2): qtd de filhos u32 | primeiro filho u32
      arquivo:              pais u16 | idioma u16 | offset do dado u32
      [v2+] ultima modificacao u64

  nomes:  tamanho u16 | hash u32 | tamanho*2 bytes em UTF-16 BE
  dados:  tamanho u32 | bytes  (se flags & 1, o bloco e um qCompress:
          u32 com o tamanho descomprimido seguido do fluxo zlib)

Uso:
    rcc.py <arquivo.rcc> --listar [filtro]
    rcc.py <arquivo.rcc> --extrair <destino> [filtro]
"""
import struct
import sys
import zlib
from pathlib import Path

FLAG_COMPRIMIDO_ZLIB = 0x01
FLAG_DIRETORIO = 0x02
FLAG_COMPRIMIDO_ZSTD = 0x04


class Rcc:
    def __init__(self, caminho):
        self.buf = Path(caminho).read_bytes()
        magic, self.versao, self.off_arvore, self.off_dados, self.off_nomes = \
            struct.unpack_from('>4sIIII', self.buf, 0)
        if magic != b'qres':
            raise ValueError('nao e um arquivo .rcc (magic %r)' % magic)
        if self.versao not in (1, 2, 3):
            raise ValueError('versao %d nao suportada' % self.versao)
        # v1 nao tem o campo de ultima modificacao
        self.tam_no = 14 if self.versao == 1 else 22

    def _no(self, indice):
        p = self.off_arvore + indice * self.tam_no
        off_nome, flags = struct.unpack_from('>IH', self.buf, p)
        if flags & FLAG_DIRETORIO:
            qtd, primeiro = struct.unpack_from('>II', self.buf, p + 6)
            return dict(nome=self._nome(off_nome), flags=flags, dir=True,
                        qtd=qtd, primeiro=primeiro)
        off_dado = struct.unpack_from('>I', self.buf, p + 10)[0]
        return dict(nome=self._nome(off_nome), flags=flags, dir=False,
                    off_dado=off_dado)

    def _nome(self, off):
        p = self.off_nomes + off
        tam = struct.unpack_from('>H', self.buf, p)[0]
        # pula o hash u32; o texto vem logo depois, em UTF-16 big-endian
        return self.buf[p + 6:p + 6 + tam * 2].decode('utf-16-be')

    def _dados(self, no):
        p = self.off_dados + no['off_dado']
        tam = struct.unpack_from('>I', self.buf, p)[0]
        bloco = self.buf[p + 4:p + 4 + tam]
        if no['flags'] & FLAG_COMPRIMIDO_ZSTD:
            raise ValueError('recurso comprimido com zstd: %s' % no['nome'])
        if no['flags'] & FLAG_COMPRIMIDO_ZLIB:
            # qCompress: u32 com o tamanho descomprimido, depois o fluxo zlib
            return zlib.decompress(bloco[4:])
        return bloco

    def percorrer(self, indice=0, prefixo=''):
        no = self._no(indice)
        caminho = prefixo + ('/' + no['nome'] if no['nome'] else '')
        if no['dir']:
            for i in range(no['qtd']):
                yield from self.percorrer(no['primeiro'] + i, caminho)
        else:
            yield caminho, no


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1

    rcc = Rcc(sys.argv[1])
    acao = sys.argv[2]
    print('versao %d | arvore @%#x | dados @%#x | nomes @%#x'
          % (rcc.versao, rcc.off_arvore, rcc.off_dados, rcc.off_nomes),
          file=sys.stderr)

    if acao == '--listar':
        filtro = sys.argv[3].lower() if len(sys.argv) > 3 else ''
        n = 0
        for caminho, _ in rcc.percorrer():
            if filtro in caminho.lower():
                print(caminho)
                n += 1
        print('%d recurso(s)' % n, file=sys.stderr)
        return 0

    if acao == '--extrair':
        destino = Path(sys.argv[3])
        filtro = sys.argv[4].lower() if len(sys.argv) > 4 else ''
        n = 0
        for caminho, no in rcc.percorrer():
            if filtro not in caminho.lower():
                continue
            alvo = destino / caminho.lstrip('/')
            alvo.parent.mkdir(parents=True, exist_ok=True)
            alvo.write_bytes(rcc._dados(no))
            n += 1
        print('%d arquivo(s) extraido(s) para %s' % (n, destino), file=sys.stderr)
        return 0

    print('acao desconhecida: %s' % acao, file=sys.stderr)
    return 1


if __name__ == '__main__':
    sys.exit(main())
