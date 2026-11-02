# blesh-setup

[ble.sh](https://github.com/akinomyoga/ble.sh) で bash を fish 風にし、[fzf](https://github.com/junegunn/fzf) と連携させ、[starship](https://starship.rs) のプロンプトを設定する最小構成のセットアップスクリプト。

- シンタックスハイライト、履歴からの自動サジェスト、補完メニュー（ble.sh の既定機能）
- 複数端末での履歴の即時共有（`bleopt history_share=1`）
- fzf 連携: `C-r` 履歴検索 / `C-t` ファイル選択 / `M-c` ディレクトリ移動 / `**<Tab>` 補完
- starship のプロンプト（[`starship.toml`](starship.toml)）
  - 左: ディレクトリ、git の状態、Python / Rust / Node のバージョン → 改行して `❯`（失敗時は赤）
  - 右: 実行時間（2秒以上のとき）、終了コード（失敗時）。時刻は表示しない
  - トランジェントプロンプト: 実行後のプロンプトを `❯` だけに縮める
- tmux の設定（[`tmux.conf`](tmux.conf)）: ホイールでコピーモード（マウス有効）、vi のキー（`v` で選択・`y` でコピー）、OSC 52 で端末のクリップボードへ

## インストール

```bash
curl -fsSL https://raw.githubusercontent.com/Mokkori-Tom/blesh-setup/main/setup.sh | bash
```

または clone して実行:

```bash
git clone https://github.com/Mokkori-Tom/blesh-setup.git && ./blesh-setup/setup.sh
```

終わったら `exec bash` で反映。

## スクリプトがすること

1. `git make gawk fzf tmux` を入れる（apt / dnf / pacman / brew / Termux の pkg に対応。Termux では sudo を使わない）。pacman / brew / Termux では starship も入れる
2. fzf が 0.48 未満なら `~/.fzf` に最新版を入れる（`fzf --bash` が必要なため）
3. starship が無ければ、公式のインストーラーで `~/.local/bin` に入れる（apt / dnf には公式のパッケージが無いため）
4. ble.sh を `~/ble.sh` に clone してビルド（既にあれば更新）
5. [`blerc`](blerc) を `~/.blerc` に、[`starship.toml`](starship.toml) を `~/.config/starship.toml`（`$STARSHIP_CONFIG` があればそこ）に、[`tmux.conf`](tmux.conf) を `~/.tmux.conf`（`~/.config/tmux/tmux.conf` だけがあればそこ）に配置。tmux が動いていれば読み込ませる
6. `~/.bashrc` の先頭に `source ~/ble.sh/out/ble.sh --noattach`、末尾に starship の初期化と `ble-attach` を追加

何度実行しても安全で、2回目以降は ble.sh の更新として動く。

## 既存の設定がある場合

既存の設定は壊さない。ファイルを書き換えるときは必ず `*.bak.<日時>` に退避する。

| 既存の状態 | 動き |
|---|---|
| `~/.bashrc` が ble.sh を読み込んでいる | その ble.sh を使う（別の場所に二重に入れない） |
| `~/.local/share/blesh` に ble.sh がある（nightly 版など） | それを `ble.sh --update` で更新して使う |
| `~/ble.sh` が git リポジトリ | `git pull --ff-only` で更新してビルド |
| `~/ble.sh` にローカルの変更がある / fast-forward できない | 更新を飛ばし、今の版のままビルド |
| `~/ble.sh` が git リポジトリでない | `out/ble.sh` があれば更新せずに使う。無ければエラーで止まる |
| `~/.blerc` の中身が違う | 置き換えずに新しい版を `~/.blerc.blesh-setup` に置き、差分を表示（`FORCE_CONFIG=1` なら置き換え） |
| `~/.config/starship.toml` の中身が違う | 同上（新しい版は `~/.config/starship.toml.blesh-setup`） |
| `~/.tmux.conf` の中身が違う | 同上（新しい版は `~/.tmux.conf.blesh-setup`） |
| `~/.bashrc` に `starship init bash` が無い | 既存の `ble-attach` の直前に追加（無ければ末尾に `ble-attach` と一緒に追加） |
| `~/.local/bin` に starship を入れた | `~/.bashrc` が設定済みでも、先頭に `PATH` の行を追加 |
| `~/.bashrc` の読み込みに `--noattach` が無い | 警告だけ出す（そのままでも動く） |
| `--noattach` で読み込んでいるのに `ble-attach` が無い | 末尾に `ble-attach` を追加 |
| 読み込み行がコメントアウトされている | 未設定とみなして追加 |
| `~/.fzf` に fzf を入れた | `~/.bashrc` が設定済みでも、先頭に `PATH` の行を追加 |
| `~/.bashrc` で `eval "$(fzf --bash)"` などを読み込んでいる | ble.sh の fzf 連携と競合するので、行番号付きで警告 |
| `~/.bashrc` が読み込む ble.sh が存在しない | エラーで止まる（`*/out/ble.sh` なら clone する） |

### オプション（環境変数）

| 変数 | 既定値 | 説明 |
|---|---|---|
| `BLESH_DIR` | `~/ble.sh` | ble.sh の clone 先（既存の ble.sh が無いときだけ使う） |
| `SKIP_PACKAGES` | （空） | `1` でパッケージのインストールを飛ばす（sudo が使えない環境向け） |
| `SKIP_STARSHIP` | （空） | `1` で starship の導入、設定ファイルの配置、`~/.bashrc` への初期化の追加を飛ばす |
| `SKIP_TMUX` | （空） | `1` で tmux の導入と `tmux.conf` の配置を飛ばす |
| `FORCE_CONFIG` | （空） | `1` で中身の違う `~/.blerc`・`starship.toml`・`tmux.conf` も退避してから置き換える（`FORCE_BLERC=1` も同じ意味） |

```bash
curl -fsSL https://raw.githubusercontent.com/Mokkori-Tom/blesh-setup/main/setup.sh | SKIP_PACKAGES=1 bash
```

## 更新

```bash
ble-update
```

## アンインストール

`~/.bashrc` の `# >>> blesh-setup >>>` 〜 `# <<< blesh-setup <<<` のブロックを消し、`~/ble.sh`、`~/.blerc`、`~/.config/starship.toml`、`~/.tmux.conf` を削除する。starship を `~/.local/bin` に入れた場合は `~/.local/bin/starship` も削除する。
