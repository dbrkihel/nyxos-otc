#!/bin/bash
# Health check do log do cliente.
#
# Conta as falhas que costumam aparecer depois de mexer em protocolo, em
# carregamento de assets ou em parsing de pacote -- os erros que nao derrubam o
# cliente e por isso passam despercebidos numa sessao de teste manual.
#
# Uso:
#   tools/logcheck.sh                  usa o log padrao na raiz do repo
#   tools/logcheck.sh /caminho/do.log  usa outro arquivo

set -u

LOG="${1:-$(dirname "$0")/../Nyxos.log}"

if [ ! -f "$LOG" ]; then
    echo "log nao encontrado: $LOG" >&2
    echo "rode o cliente uma vez, ou passe o caminho como argumento." >&2
    exit 1
fi

conta() {
    printf '%-18s %s\n' "$1" "$(grep -cE "$2" "$LOG")"
}

echo "log: $LOG"
echo

conta "exceptions:"      'parse message exception'
conta "decompress-fail:" 'invalid size of decompressed|failed to decompress'
conta "no-thing:"        'no thing at pos'
conta "trailing-cd:"     'cross-packet split'
conta "tokformat-err:"   'tokformat'
conta "magicshield-err:" 'getMagicShield|useMagicShield'
conta "blessing-err:"    'getBlessingStatus'
conta "cyclopedia-err:"  'setCyclopediaMarketList'
conta "erros gerais:"    'ERROR|FATAL'

echo
# Se esta linha nao aparece, o cliente nem chegou a carregar os sprites --
# qualquer contagem zerada acima e falso alivio.
echo "chegou a carregar assets: $(grep -cE 'SpriteSheetLoader: parsed' "$LOG")"
