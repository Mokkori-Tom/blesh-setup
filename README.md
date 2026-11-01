# blesh-setup

[ble.sh](https://github.com/akinomyoga/ble.sh) で bash を fish 風にし、[fzf](https://github.com/junegunn/fzf) と連携させる最小構成のセットアップスクリプト。

- シンタックスハイライト、履歴からの自動サジェスト、補完メニュー（ble.sh の既定機能）
- 複数端末での履歴の即時共有（`bleopt history_share=1`）
- fzf 連携: `C-r` 履歴検索 / `C-t` ファイル選択 / `M-c` ディレクトリ移動 / `**<Tab>` 補完
- starship があればトランジェントプロンプト（実行後のプロンプトを `❯` だけに縮める）
- starship の設定例: [`starship.toml`](starship.toml)（`setup.sh` では配置しないので、使うときは `~/.config/starship.toml` にコピーする）

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

1. `git make gawk fzf` を入れる（apt / dnf / pacman / brew / Termux の pkg に対応。Termux では sudo を使わない）
2. fzf が 0.48 未満なら `~/.fzf` に最新版を入れる（`fzf --bash` が必要なため）
3. ble.sh を `~/ble.sh` に clone してビルド（既にあれば更新）
4. [`blerc`](blerc) を `~/.blerc` に配置
5. `~/.bashrc` の先頭に `source ~/ble.sh/out/ble.sh --noattach`、末尾に `ble-attach` を追加

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
| `~/.blerc` の中身が違う | 置き換えずに新しい版を `~/.blerc.blesh-setup` に置き、差分を表示（`FORCE_BLERC=1` なら置き換え） |
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
| `FORCE_BLERC` | （空） | `1` で中身の違う `~/.blerc` も退避してから置き換える |

```bash
curl -fsSL https://raw.githubusercontent.com/Mokkori-Tom/blesh-setup/main/setup.sh | SKIP_PACKAGES=1 bash
```

## 更新

```bash
ble-update
```

## アンインストール

`~/.bashrc` の `# >>> blesh-setup >>>` 〜 `# <<< blesh-setup <<<` のブロックを消し、`~/ble.sh` と `~/.blerc` を削除する。
