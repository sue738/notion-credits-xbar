# Notion のクレジットを Mac のメニューバーに

Notion を開かなくても、Notion AI のクレジットをどれだけ使っているかがわかります。

[English](README.md)

```
N 2,060                                    ← メニューバー
───────────────────────────────────────
Used this period 2,060 (19 agents you can edit)
Personal Notion AI: 182 runs, 0 credits (no limit)
───────────────────────────────────────
Ticket triage agent    1,043 / limit 3,000
Post-mortem manager      378 / limit 3,750
Spec writer              332 / limit 7,500
───────────────────────────────────────
Create a token in Notion
Set token…
```

表示は英語です。

## 数字の意味

| ワークスペースの設定 | メニューバーの数字 |
| --- | --- |
| 1人あたりのクレジット上限がある | 今期の**残り**（例 `N 680`） |
| 1人あたりの上限がない | 自分が編集できるカスタムエージェントの、今期の**使用量**の合計（例 `N 2,060`） |

カスタムエージェントは、特に設定しなければ持ち主のクレジットを使います。なので2つめの数字は「自分が使っている分」に近い値です。
上限の残りが30%を切ったエージェントは**橙**、10%を切ると**赤**になります。

## 入れ方（5分ほど）

Mac と、Notion の Business か Enterprise のワークスペースが必要です。

1. **xbar を入れる**
   [xbarapp.com](https://xbarapp.com) からダウンロードして開きます。
   Homebrew を使っているなら `brew install --cask xbar` でも入ります。
2. **プラグインを置く**
   [`notion-credits.15m.sh`](https://raw.githubusercontent.com/sue738/notion-credits-xbar/main/notion-credits.15m.sh) を保存します（右クリック →「リンク先を別名で保存」）。
   xbar のメニューで **Open plugin folder** を選び、開いたフォルダにファイルを移します。
   **Refresh all** を選ぶと、メニューバーに **N ?** が出ます。
3. **トークンを作る**
   **N ?** →「**Create a token in Notion**」→「**新しいトークン**」と進みます。
   名前は何でもかまいません。「Notion API」にチェックを入れたまま作成し、表示されたトークン（`ntn_` で始まる文字列）をコピーします。
4. **トークンを登録する**（どちらか一方で大丈夫です）
   - **メニューから:** **N ?** →「**Set token…**」を選び、貼り付けて **Save** を押します。
   - **ターミナルから:**
     ```sh
     ~/Library/Application\ Support/xbar/plugins/notion-credits.15m.sh set-token
     ```
     聞かれたら貼り付けます（貼り付けても画面には何も出ません）。そのあと xbar で **Refresh all** を選びます。

数字が出たら完了です。15分ごとに更新されます。

<details>
<summary>ターミナルでまとめて入れる</summary>

```sh
brew install --cask xbar
open -a xbar
PLUGINS=~/Library/Application\ Support/xbar/plugins
mkdir -p "$PLUGINS"
curl -fsSL https://raw.githubusercontent.com/sue738/notion-credits-xbar/main/notion-credits.15m.sh -o "$PLUGINS/notion-credits.15m.sh"
chmod +x "$PLUGINS/notion-credits.15m.sh"
"$PLUGINS/notion-credits.15m.sh" set-token
```

</details>

## コマンド

| コマンド | すること |
| --- | --- |
| `notion-credits.15m.sh set-token` | トークンを Keychain に保存します。その場で聞くか、パイプで渡せます |
| `notion-credits.15m.sh remove-token` | 保存したトークンを消します |
| `notion-credits.15m.sh` | メニューの中身を1回だけ表示します（動くかの確認に使えます） |

## よくある質問

**トークンは安全？**
Mac の Keychain に `notion-pat` という名前で保存され、送り先は `api.notion.com` だけです。トークンがあれば Notion で自分が見られるものを読めるので、人には渡さないでください。

**「新しいトークン」のボタンがない**
ワークスペースの管理者が、トークンを作れる人を絞っています。管理者に相談してください。

**メニューバーが `N !` になった**
メニューを開くとエラーが出ています。`401` はトークンが違うか期限切れです。トークンを作り直して、もう一度「Set token…」で登録してください。

**更新の間隔を変えたい**
ファイル名を変えます。`notion-credits.5m.sh` なら5分ごと、`notion-credits.1h.sh` なら1時間ごとです。

**やめたい**
`notion-credits.15m.sh remove-token` を実行してから、プラグインのフォルダからファイルを消します。Notion の画面でトークンを取り消すこともできます。

## しくみ

Notion API の [Retrieve agent insights](https://developers.notion.com/reference/notion-agent-apis/retrieve-agent-insights)（公開ベータ）を呼んでいます。
まず自分の Notion AI（`notion_ai`）を読み、次に自分が編集できるカスタムエージェントを1つずつ読みます。
見るだけの権限しかないエージェントは飛ばします。それ以外のものは読みません。

## ライセンス

MIT
