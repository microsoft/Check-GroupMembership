# Check-GroupMembership

Azure Active Directory と Exchange Online 間でメンバー情報が一致していないグループがあるかチェックします。

## ダウンロード方法

[release](https://github.com/Microsoft/Check-GroupMembership/releases) ページから Check-GroupMembership をダウンロードしてください。

## 実行方法

1. Check-GroupMembership をダウンロードして実行端末に保存します。
2. Windows PowerShell を起動してスクリプト ファイルを保存したフォルダーに移動します.
3. 以下のようにコマンドを実行します。(事前に Azure Active Directory や Exchange Online に PowerShell で接続しておく必要はありません)

    ~~~powershell
    .\Check-GroupMembership.ps1
    ~~~

4. [Windows PowerShell 資格情報の要求] ダイアログ ボックスが表示されるので Office 365 管理者の資格情報を入力してください。
5. スクリプトと同じフォルダーに CSV ファイルが作成されます。(メンバー情報が一致していないグループが無い場合でも空のファイルが作成されます)

## 前提条件

実行端末には Azure Active Directory V1 モジュール (MSOnline) がインストールされている必要があります。詳細は[こちら](https://docs.microsoft.com/en-us/powershell/azure/active-directory/overview?view=azureadps-1.0)のページを参照してください。

## 構文

```powershell
.\Check-GroupMembership.ps1 [<CommonParameters>]
```

## フィードバック

スクリプトに関するフィードバックは [Issues](https://github.com/Microsoft/Check-GroupMembership/issues) に投稿してください。日本語でも構いません。

本プロジェクトへの参加に関しては、[英語版 README の Contributing セクション](https://github.com/Microsoft/Check-GroupMembership/#contributing)をご参照ください。