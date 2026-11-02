#!/usr/bin/env bash
# ble.sh（fish 風の入力補完）と fzf 連携、starship のプロンプトのセットアップ
#
#   curl -fsSL https://raw.githubusercontent.com/Mokkori-Tom/blesh-setup/main/setup.sh | bash
#
# 何度実行しても同じ状態になる（2回目以降は ble.sh の更新として動く）。
# 既存の設定は壊さない: 既にある ble.sh はその場所のまま更新し、
# 中身の違う ~/.blerc や ~/.config/starship.toml は置き換えずに新しい版を横に置く。
# 環境変数:
#   BLESH_DIR=~/ble.sh   ble.sh の clone 先（既存の ble.sh が無いときだけ使う）
#   SKIP_PACKAGES=1      パッケージのインストールを飛ばす（sudo なしの環境向け）
#   SKIP_STARSHIP=1      starship の導入と設定を飛ばす
#   SKIP_TMUX=1          tmux の導入と設定を飛ばす
#   FORCE_CONFIG=1       中身の違う ~/.blerc・starship.toml・tmux.conf も退避してから置き換える
#                        （FORCE_BLERC=1 も同じ意味）
set -euo pipefail

BLESH_DIR=${BLESH_DIR:-$HOME/ble.sh}
REPO_RAW=https://raw.githubusercontent.com/Mokkori-Tom/blesh-setup/main
FZF_MIN=0.48.0
BASHRC=$HOME/.bashrc
BLERC=$HOME/.blerc
STARSHIP_TOML=${STARSHIP_CONFIG:-$HOME/.config/starship.toml}
# tmux は ~/.config/tmux/tmux.conf があればそちらを読む
TMUX_CONF=$HOME/.tmux.conf
[[ -f $HOME/.config/tmux/tmux.conf && ! -f $TMUX_CONF ]] && TMUX_CONF=$HOME/.config/tmux/tmux.conf
FORCE_CONFIG=${FORCE_CONFIG:-${FORCE_BLERC-}}
STAMP=$(date +%Y%m%d%H%M%S)

BLESH_SRC=      # 読み込む ble.sh のパス
BLESH_LINE=     # ~/.bashrc 内の既存の読み込み行
FZF_LOCAL=      # ~/.fzf に fzf を入れたか
STARSHIP_LOCAL= # ~/.local/bin に starship を入れたか

info() { printf '\e[1;34m==>\e[m %s\n' "$*"; }
warn() { printf '\e[1;33mwarn:\e[m %s\n' "$*" >&2; }
die() { printf '\e[1;31merror:\e[m %s\n' "$*" >&2; exit 1; }
tilde() { printf '%s' "${1/#$HOME/\~}"; }

# --- 1. 依存パッケージ ---------------------------------------------------------
install_packages() {
  [[ ${SKIP_PACKAGES-} ]] && return
  # starship は apt / dnf の公式リポジトリに無いので、それらでは ensure_starship で入れる
  local starship=starship
  [[ ${SKIP_STARSHIP-} ]] && starship=
  local tmux=tmux
  [[ ${SKIP_TMUX-} ]] && tmux=
  # Termux は apt-get も持つが sudo は無いので、apt より先に判定する
  if [[ ${TERMUX_VERSION-} || ${PREFIX-} == */com.termux/* ]]; then
    pkg install -y git make gawk curl fzf $starship $tmux
    return
  fi
  # curl は fzf が古いとき(Debian 12 は 0.38)に ~/.fzf へ最新版を取るのと、starship の導入に使う
  local sudo=
  if ((EUID != 0)); then
    command -v sudo >/dev/null || die "sudo がありません。root で実行するか SKIP_PACKAGES=1 を付けて git make gawk curl fzf を手動で入れてください"
    sudo=sudo
  fi
  if command -v apt-get >/dev/null; then
    $sudo apt-get update -qq && $sudo apt-get install -y -qq git make gawk curl fzf $tmux
  elif command -v dnf >/dev/null; then
    $sudo dnf install -y -q git make gawk curl fzf $tmux
  elif command -v pacman >/dev/null; then
    $sudo pacman -S --needed --noconfirm git make gawk curl fzf $starship $tmux
  elif command -v brew >/dev/null; then
    brew install git make gawk curl fzf $starship $tmux
  else
    warn "パッケージマネージャが見つからない。git make gawk curl fzf を手動で入れてください"
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
  command -v curl >/dev/null || command -v wget >/dev/null ||
    die "fzf $FZF_MIN 以上が要りますが、取ってくるための curl も wget もありません。curl を入れてから実行し直してください"
  if [[ -d $HOME/.fzf/.git ]]; then
    git -C "$HOME/.fzf" pull --ff-only -q
  else
    git clone -q --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  fi
  local log
  log=$("$HOME/.fzf/install" --bin 2>&1) || { printf '%s\n' "$log" >&2; die "fzf のインストールに失敗しました"; }
  export PATH=$HOME/.fzf/bin:$PATH
  fzf_ok || die "fzf $FZF_MIN 以上を用意できませんでした"
  FZF_LOCAL=1
}

# --- 3. starship ---------------------------------------------------------------
ensure_starship() {
  [[ ${SKIP_STARSHIP-} ]] && return
  command -v starship >/dev/null && return
  if [[ -x $HOME/.local/bin/starship ]]; then # 前回入れたもの（PATH に無いだけ）
    export PATH=$HOME/.local/bin:$PATH
    STARSHIP_LOCAL=1
    return
  fi
  info "starship が無いので公式のインストーラーで ~/.local/bin に入れます"
  mkdir -p "$HOME/.local/bin"
  local log
  if log=$(curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" 2>&1); then
    export PATH=$HOME/.local/bin:$PATH
    STARSHIP_LOCAL=1
  else
    printf '%s\n' "$log" | tail -20 | sed 's/^/    /' >&2
    warn "starship を入れられませんでした。プロンプトは bash の既定のまま続けます"
  fi
}

# --- 4. 既存の ble.sh を探す -----------------------------------------------------
# ~/.bashrc が読み込んでいるもの > $BLESH_DIR > nightly 版の既定の場所 の順
detect_blesh() {
  touch "$BASHRC"
  BLESH_LINE=$(grep -E '^[^#]*(source|\.)[[:space:]]+[^[:space:]]*ble\.sh' "$BASHRC" | head -1) || true
  if [[ $BLESH_LINE ]]; then
    local path
    path=$(grep -oE "[^[:space:];&|\"']*ble\.sh" <<<"$BLESH_LINE" | tail -1)
    path=${path/#\~/$HOME}
    path=${path//\$\{HOME\}/$HOME}
    path=${path//\$HOME/$HOME}
    if [[ -f $path || $path == */out/ble.sh ]]; then # */out/ble.sh なら無くても clone できる
      BLESH_SRC=$path
      info "~/.bashrc が読み込んでいる ble.sh を使います ($(tilde "$path"))"
      return
    fi
    die "~/.bashrc が読み込む ble.sh ($path) が見つかりません。行を直すか消してから再実行してください"
  fi
  if [[ -e $BLESH_DIR ]]; then
    BLESH_SRC=$BLESH_DIR/out/ble.sh
  elif [[ -f $HOME/.local/share/blesh/ble.sh ]]; then
    BLESH_SRC=$HOME/.local/share/blesh/ble.sh
    info "既存の ble.sh を使います ($(tilde "$BLESH_SRC"))"
  else
    BLESH_SRC=$BLESH_DIR/out/ble.sh
  fi
}

# --- 5. ble.sh の取得・更新 ------------------------------------------------------
install_blesh() {
  if [[ $BLESH_SRC != */out/ble.sh ]]; then
    # make install や nightly 版で入れたもの: ble.sh 自身の更新処理に任せる
    if [[ -O $BLESH_SRC ]]; then
      info "ble.sh を更新します ($(tilde "$BLESH_SRC") --update)"
      local log
      if ! log=$(bash "$BLESH_SRC" --update 2>&1); then
        printf '%s\n' "$log" | tail -20 | sed 's/^/    /' >&2
        warn "ble.sh の更新に失敗しました。既存の版のまま続けます"
      fi
    else
      warn "$(tilde "$BLESH_SRC") は別のユーザーの所有なので更新を飛ばします（パッケージマネージャで更新してください）"
    fi
    return
  fi

  local dir=${BLESH_SRC%/out/ble.sh}
  for cmd in git make; do
    command -v "$cmd" >/dev/null || die "$cmd が必要です"
  done
  if [[ ! -e $dir ]]; then
    info "ble.sh を clone します ($(tilde "$dir"))"
    git clone -q --recursive --depth 1 --shallow-submodules \
      https://github.com/akinomyoga/ble.sh.git "$dir"
  elif [[ ! -d $dir/.git ]]; then
    [[ -f $BLESH_SRC ]] || die "$(tilde "$dir") は ble.sh の git リポジトリではありません。退避するか BLESH_DIR で別の場所を指定してください"
    warn "$(tilde "$dir") は git リポジトリではないので、更新せずにそのまま使います"
    return
  elif [[ $(git -C "$dir" status --porcelain --untracked-files=no) ]]; then
    warn "$(tilde "$dir") にローカルの変更があるので、git pull を飛ばしてビルドだけします"
  elif ! git -C "$dir" pull --ff-only -q; then
    warn "$(tilde "$dir") を fast-forward で更新できないので、今の版のままビルドします"
  else
    info "ble.sh を最新の状態にしました ($(tilde "$dir"))"
    git -C "$dir" submodule update --init --recursive -q
  fi
  make -s -C "$dir" >/dev/null || die "ble.sh のビルドに失敗しました"
  info "ble.sh $(git -C "$dir" log -1 --format='%h (%cs)')"
}

# --- 6. 設定ファイル（~/.blerc, starship.toml, tmux.conf） ---------------------------------
# install_config <リポジトリ内の名前> <配置先>
# 無ければ配置し、同じなら何もしない。中身が違えば置き換えずに <配置先>.blesh-setup を置く
install_config() {
  local name=$1 dest=$2 src tmp shown
  shown=$(tilde "$dest")
  src=$(dirname "${BASH_SOURCE[0]:-}")/$name
  tmp=$(mktemp)
  if [[ -f $src ]]; then
    cp "$src" "$tmp"
  else # curl | bash で実行されたとき
    curl -fsSL "$REPO_RAW/$name" -o "$tmp" || die "$REPO_RAW/$name を取得できませんでした"
  fi
  mkdir -p "$(dirname "$dest")"

  if [[ ! -f $dest ]]; then
    mv "$tmp" "$dest"
    info "$shown を配置しました"
  elif cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"
  elif [[ $FORCE_CONFIG ]]; then
    cp "$dest" "$dest.bak.$STAMP"
    mv "$tmp" "$dest"
    info "$shown を置き換えました（元の版は $shown.bak.$STAMP）"
  else
    mv "$tmp" "$dest.blesh-setup"
    warn "$shown は手元の版と違うので置き換えません。新しい版は $shown.blesh-setup に置きました"
    diff -u --label "$shown" --label "$shown.blesh-setup" "$dest" "$dest.blesh-setup" | sed 's/^/    /' >&2 || true
    warn "取り込むなら手で反映するか、FORCE_CONFIG=1 を付けて再実行してください"
    return 1
  fi
}

install_configs() {
  if ! install_config blerc "$BLERC"; then
    grep -qE '^[^#]*fzf-key-bindings' "$BLERC" ||
      warn "今の ~/.blerc では fzf 連携 (ble-import integration/fzf-key-bindings) が有効になっていません"
  fi
  [[ ${SKIP_STARSHIP-} ]] || install_config starship.toml "$STARSHIP_TOML" || true
  if [[ ! ${SKIP_TMUX-} ]] && install_config tmux.conf "$TMUX_CONF"; then
    # 動いている tmux にもすぐ効かせる（新しく開くセッションは自動で読む）
    if [[ ${TMUX-} ]] || tmux info >/dev/null 2>&1; then
      tmux source-file "$TMUX_CONF" 2>/dev/null && info "動いている tmux に $(tilde "$TMUX_CONF") を読み込ませました"
    fi
  fi
}

# --- 7. ~/.bashrc ----------------------------------------------------------------
install_bashrc() {
  local head= need_attach= starship_init=

  if [[ ! $BLESH_LINE ]]; then
    head+="[[ \$- == *i* ]] && source $(tilde "$BLESH_SRC") --noattach"$'\n'
    need_attach=1
  elif [[ $BLESH_LINE != *--noattach* ]]; then
    warn "~/.bashrc の ble.sh の読み込みに --noattach がありません（動きますが、推奨は --noattach で読み込み末尾で ble-attach する形）"
  elif ! grep -qE '^[^#]*ble-attach' "$BASHRC"; then
    info "~/.bashrc に ble-attach が無いので末尾に追加します（無いと ble.sh が有効になりません）"
    need_attach=1
  fi
  # ~/.fzf に入れた fzf を使うには PATH が要る（ble.sh 設定済みの ~/.bashrc でも足す）
  if [[ $FZF_LOCAL ]] && ! grep -qE '^[^#]*\.fzf/bin' "$BASHRC"; then
    head='[[ -d ~/.fzf/bin ]] && PATH=~/.fzf/bin:$PATH'$'\n'$head
  fi
  if [[ $STARSHIP_LOCAL ]] && ! grep -qE '^[^#]*\.local/bin' "$BASHRC"; then
    head='[[ -d ~/.local/bin ]] && PATH=~/.local/bin:$PATH'$'\n'$head
  fi
  # starship の初期化は ble.sh を読み込んだ後、ble-attach より前に置く
  if [[ ! ${SKIP_STARSHIP-} ]] && ! grep -qE '^[^#]*starship init bash' "$BASHRC"; then
    starship_init='command -v starship >/dev/null && eval "$(starship init bash)"'
  fi

  if [[ $head || $need_attach || $starship_init ]]; then
    cp "$BASHRC" "$BASHRC.bak.$STAMP"
    info "~/.bashrc を ~/.bashrc.bak.$STAMP に退避"
    {
      # ble.sh の読み込みは「対話シェルでなければ return」より前、先頭に置く必要がある
      if [[ $head ]]; then
        printf '# >>> blesh-setup >>>\n%s# <<< blesh-setup <<<\n\n' "$head"
      fi
      if [[ $starship_init && ! $need_attach ]] && grep -qE '^[^#]*ble-attach' "$BASHRC"; then
        # 既存の ble-attach の直前に差し込む
        BLOCK="# >>> blesh-setup >>>"$'\n'"$starship_init"$'\n'"# <<< blesh-setup <<<" \
          awk '!done && /^[^#]*ble-attach/ { print ENVIRON["BLOCK"]; done = 1 } { print }' "$BASHRC"
      else
        cat "$BASHRC"
        if [[ $starship_init || $need_attach ]]; then
          printf '\n# >>> blesh-setup >>>\n'
          [[ ! $starship_init ]] || printf '%s\n' "$starship_init"
          [[ ! $need_attach ]] || printf '((_ble_bash)) && ble-attach\n'
          printf '# <<< blesh-setup <<<\n'
        fi
      fi
    } >"$BASHRC.tmp.$STAMP"
    mv "$BASHRC.tmp.$STAMP" "$BASHRC"
    info "~/.bashrc に ble.sh の設定を追加しました"
  else
    info "~/.bashrc は設定済みなので変更しません"
  fi

  # fzf 本体の bash 用設定は ble.sh のキー割り当てと競合する
  local conflicts
  conflicts=$(grep -nE '^[^#]*(fzf --bash|fzf/shell/(key-bindings|completion)\.bash|\.fzf\.bash|fzf/examples/(key-bindings|completion)\.bash)' "$BASHRC") || true
  if [[ $conflicts ]]; then
    warn "~/.bashrc で fzf 本体の bash 用設定を読み込んでいます。ble.sh の fzf 連携 (~/.blerc) と競合するので、ble.sh を使うときは読み込まないようにしてください（ble.sh 以外のシェル専用の分岐ならそのままで構いません）"
    sed 's/^/    ~\/.bashrc:/' <<<"$conflicts" >&2
  fi
}

main() {
  install_packages
  ensure_fzf
  ensure_starship
  detect_blesh
  install_blesh
  install_configs
  install_bashrc
  info "完了。'exec bash' で反映されます"
}

main "$@"
