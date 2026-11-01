# blesh-setup

[ble.sh](https://github.com/akinomyoga/ble.sh) で bash を fish 風にし、[fzf](https://github.com/junegunn/fzf) と連携させる最小構成のセットアップスクリプト。

- シンタックスハイライト、履歴からの自動サジェスト、補完メニュー（ble.sh の既定機能）
- 複数端末での履歴の即時共有（`bleopt history_share=1`）
- fzf 連携: `C-r` 履歴検索 / `C-t` ファイル選択 / `M-c` ディレクトリ移動 / `**<Tab>` 補完
- starship があればトランジェントプロンプト（実行後のプロンプトを `❯` だけに縮める）

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

既存の `~/.blerc` と `~/.bashrc` は `*.bak.<日時>` に退避する。`~/.bashrc` に既に ble.sh の設定があれば触らない。何度実行しても安全で、2回目以降は ble.sh の更新として動く。

### オプション（環境変数）

| 変数 | 既定値 | 説明 |
|---|---|---|
| `BLESH_DIR` | `~/ble.sh` | ble.sh の clone 先 |
| `SKIP_PACKAGES` | （空） | `1` でパッケージのインストールを飛ばす（sudo が使えない環境向け） |

```bash
curl -fsSL https://raw.githubusercontent.com/Mokkori-Tom/blesh-setup/main/setup.sh | SKIP_PACKAGES=1 bash
```

## 更新

```bash
ble-update
```

## アンインストール

`~/.bashrc` の `# >>> blesh-setup >>>` 〜 `# <<< blesh-setup <<<` の2ブロックを消し、`~/ble.sh` と `~/.blerc` を削除する。
