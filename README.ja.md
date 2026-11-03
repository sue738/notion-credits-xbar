# Notion のクレジットを Mac のメニューバーに

Notion を開かなくても、Notion AI のクレジットをどれだけ使っているかがわかります。

[English](README.md)

```
N 2,060                                              ← メニューバー
──────────────────────────────────────────────
You: Notion AI 183 runs this period
Standard ▱▱▱▱▱▱▱▱▱▱▱▱      0 / 1,500
Select   ▱▱▱▱▱▱▱▱▱▱▱▱      ? / 500
──────────────────────────────────────────────
Custom Agents you can edit: 2,060 used (19 agents)
▰▰▰▰▱▱▱▱▱▱▱▱   1,043 / 3,000  Ticket triage agent
▰▱▱▱▱▱▱▱▱▱▱▱     378 / 3,750  Post-mortem manager
▰▱▱▱▱▱▱▱▱▱▱▱     332 / 7,500  Spec writer
14 agents with no usage this period
──────────────────────────────────────────────
Open Notion · Refresh · Create a token in Notion · Set token…
```

表示は英語です。

## 数字の意味

Business と Enterprise では、メンバー1人ごとに毎月2種類の枠があります。毎月リセットされ、2つを合わせて使うことはできません。

| 枠 | 使われる機能 |
| --- | --- |
| **Standard** 1,500 | Notion エージェント（自動）、AI での編集、AI ブロック、翻訳 |
| **Select** 500 | モデルを自分で選んだ Notion エージェント、自分が持ち主のカスタムエージェント（既定のとき） |

- **メニューバー:** 1人あたりの上限がワークスペースで決まっていれば、今月の**残り**を出します。決まっていなければ、自分が編集できるカスタムエージェントの今月の**使用量**の合計です。
- **You:** 自分の使用量をバーで出します。API は Standard と Select を分けずに合計だけを返すので、Standard の枠に対して描いています。
- **Custom Agents:** エージェントごとに、そのエージェントの上限に対する使用量です。残りが30%を切ると**橙**、10%を切ると**赤**になります。

プランによって枠の量が違うときは、ファイルの先頭にある `NOTION_STANDARD_CREDITS` と `NOTION_SELECT_CREDITS` を書き換えてください。

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
