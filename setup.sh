#!/usr/bin/env bash
# ble.sh（fish 風の入力補完）と fzf 連携のセットアップ
#
#   curl -fsSL https://raw.githubusercontent.com/Mokkori-Tom/blesh-setup/main/setup.sh | bash
#
# 何度実行しても同じ状態になる（2回目以降は ble.sh の更新として動く）。
# 環境変数:
#   BLESH_DIR=~/ble.sh   ble.sh の clone 先
#   SKIP_PACKAGES=1      パッケージのインストールを飛ばす（sudo なしの環境向け）
set -euo pipefail

BLESH_DIR=${BLESH_DIR:-$HOME/ble.sh}
REPO_RAW=https://raw.githubusercontent.com/Mokkori-Tom/blesh-setup/main
FZF_MIN=0.48.0
BASHRC=$HOME/.bashrc
BLERC=$HOME/.blerc
STAMP=$(date +%Y%m%d%H%M%S)

info() { printf '\e[1;34m==>\e[m %s\n' "$*"; }
warn() { printf '\e[1;33mwarn:\e[m %s\n' "$*" >&2; }
die() { printf '\e[1;31merror:\e[m %s\n' "$*" >&2; exit 1; }

# --- 1. 依存パッケージ ---------------------------------------------------------
install_packages() {
  [[ ${SKIP_PACKAGES-} ]] && return
  # Termux は apt-get も持つが sudo は無いので、apt より先に判定する
  if [[ ${TERMUX_VERSION-} || ${PREFIX-} == */com.termux/* ]]; then
    pkg install -y git make gawk fzf
    return
  fi
  local sudo=
  if ((EUID != 0)); then
    command -v sudo >/dev/null || die "sudo がありません。root で実行するか SKIP_PACKAGES=1 を付けて git make gawk fzf を手動で入れてください"
    sudo=sudo
  fi
  if command -v apt-get >/dev/null; then
    $sudo apt-get update -qq && $sudo apt-get install -y -qq git make gawk fzf
  elif command -v dnf >/dev/null; then
    $sudo dnf install -y -q git make gawk fzf
  elif command -v pacman >/dev/null; then
    $sudo pacman -S --needed --noconfirm git make gawk fzf
  elif command -v brew >/dev/null; then
    brew install git make gawk fzf
  else
    warn "パッケージマネージャが見つからない。git make gawk fzf を手動で入れてください"
  fi
}

# --- 2. fzf のバージョン確認（fzf --bash は 0.48 以上が必要） -----------------
fzf_ok() {
  command -v fzf >/dev/null || return 1
  local v
  v=$(fzf --version | awk '{print $1}')
  [[ $(printf '%s\n' "$FZF_MIN" "$v" | sort -V | head -1) == "$FZF_MIN" ]]
}

ensure_fzf() {
  fzf_ok && return
  info "fzf が無いか古いので ~/.fzf に最新版を入れます"
  if [[ -d $HOME/.fzf/.git ]]; then
    git -C "$HOME/.fzf" pull --ff-only -q
  else
    git clone -q --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  fi
  "$HOME/.fzf/install" --bin >/dev/null
  export PATH=$HOME/.fzf/bin:$PATH
  fzf_ok || die "fzf $FZF_MIN 以上を用意できませんでした"
  FZF_LOCAL=1
}

# --- 3. ble.sh の取得とビルド ----------------------------------------------------
install_blesh() {
  for cmd in git make; do
    command -v "$cmd" >/dev/null || die "$cmd が必要です"
  done
  if [[ -d $BLESH_DIR/.git ]]; then
    info "ble.sh を更新します ($BLESH_DIR)"
    git -C "$BLESH_DIR" pull --ff-only -q
    git -C "$BLESH_DIR" submodule update --init --recursive -q
  else
    info "ble.sh を clone します ($BLESH_DIR)"
    git clone -q --recursive --depth 1 --shallow-submodules \
      https://github.com/akinomyoga/ble.sh.git "$BLESH_DIR"
  fi
  make -s -C "$BLESH_DIR" >/dev/null
  info "ble.sh $(git -C "$BLESH_DIR" log -1 --format='%h (%cs)')"
}

# --- 4. ~/.blerc ---------------------------------------------------------------
install_blerc() {
  local src tmp
  src=$(dirname "${BASH_SOURCE[0]:-}")/blerc
  tmp=$(mktemp)
  if [[ -f $src ]]; then
    cp "$src" "$tmp"
  else # curl | bash で実行されたとき
    curl -fsSL "$REPO_RAW/blerc" -o "$tmp"
  fi
  if [[ -f $BLERC ]] && cmp -s "$tmp" "$BLERC"; then
    rm -f "$tmp"
    return
  fi
  [[ -f $BLERC ]] && cp "$BLERC" "$BLERC.bak.$STAMP" && info "既存の ~/.blerc を ~/.blerc.bak.$STAMP に退避"
  mv "$tmp" "$BLERC"
  info "~/.blerc を配置しました"
}

# --- 5. ~/.bashrc ----------------------------------------------------------------
install_bashrc() {
  touch "$BASHRC"
  if grep -q 'ble.sh/out/ble.sh\|blesh/ble.sh' "$BASHRC"; then
    info "~/.bashrc には既に ble.sh の設定があるので変更しません"
    return
  fi
  cp "$BASHRC" "$BASHRC.bak.$STAMP"
  info "~/.bashrc を ~/.bashrc.bak.$STAMP に退避"

  local head tail
  head="# >>> blesh-setup >>>"$'\n'
  [[ ${FZF_LOCAL-} ]] && head+='[[ -d ~/.fzf/bin ]] && PATH=~/.fzf/bin:$PATH'$'\n'
  head+="[[ \$- == *i* ]] && source ${BLESH_DIR/#$HOME/\~}/out/ble.sh --noattach"$'\n'
  head+="# <<< blesh-setup <<<"
  tail=$'\n'"# >>> blesh-setup >>>"$'\n'"((_ble_bash)) && ble-attach"$'\n'"# <<< blesh-setup <<<"

  # ble.sh の読み込みは「対話シェルでなければ return」より前、先頭に置く必要がある
  { printf '%s\n\n' "$head"; cat "$BASHRC"; printf '%s\n' "$tail"; } >"$BASHRC.tmp.$STAMP"
  mv "$BASHRC.tmp.$STAMP" "$BASHRC"
  info "~/.bashrc の先頭と末尾に ble.sh の設定を追加しました"
}

main() {
  install_packages
  ensure_fzf
  install_blesh
  install_blerc
  install_bashrc
  info "完了。'exec bash' で反映されます"
}

main "$@"
