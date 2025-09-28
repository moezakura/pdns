# PowerDNS Recursor with Adblock and Overrides (Docker)

この構成は PowerDNS Recursor を Docker 上で実行し、
- `config/powerdns/blocked_domains.txt` のドメインを NXDOMAIN でブロック
- `config/powerdns/hosts_overrides.txt` の静的エントリで A レコードを上書き（`mox.si` と `*.mox.si` を 192.168.10.153 に解決）
を行います。

## 使い方

1) 必要なファイルは以下の通りです。
- `compose.yml`
- `config/powerdns/recursor.conf`
- `config/powerdns/recursor-adblock.lua`
- `config/powerdns/blocked_domains.txt`
- `config/powerdns/hosts_overrides.txt`

2) 起動

```
docker compose up -d
```

3) 動作確認

- 上書き解決の確認（A レコード）

```
dig @127.0.0.1 mox.si A +short
# => 192.168.10.153

dig @127.0.0.1 sub.mox.si A +short
# => 192.168.10.153
```

- ブロック確認（例）

```
dig @127.0.0.1 doubleclick.net A +short
# 何も返らない (NXDOMAIN)
```

## リストの更新

- ブロック対象: `config/powerdns/blocked_domains.txt`
  - 空白・末尾のドットは無視されます
  - `#` から始まる行はコメント
  - `example.com` を書くと `example.com` 自体とそのサブドメイン（`*.example.com`）もブロックされます
- 静的上書き: `config/powerdns/hosts_overrides.txt`
  - 形式: `domain=IPv4`
  - ワイルドカード: `*.example.com=1.2.3.4`
  - 例: 本リポジトリには既定で
    - `mox.si=192.168.10.153`
    - `*.mox.si=192.168.10.153`
    を含めています

変更後は以下で再読み込み（再起動）してください。

```
docker compose restart pdns-recursor
```

## 補足

- コンテナは `53/udp` と `53/tcp` をホストへ公開します。既にローカルで DNS が稼働している場合はポート競合に注意してください。
- 企業/自宅ネットワーク向けには `config/powerdns/recursor.conf` の `allow-from` を適切な CIDR に絞ることを推奨します。

## トラブルシュート

- 応答が無い/タイムアウトする場合:
  - コンテナの状態とログを確認: `docker compose ps` / `docker compose logs -f pdns-recursor`
  - ポート競合が無いか確認: `sudo lsof -i :53 -P -n`（`systemd-resolved` などが 53 を占有していないか）
  - 設定ファイルのパースエラーがないかログを確認（`recursor.conf` はキー=値形式に修正済み）
  - ファイルマウントの確認: `config/powerdns` が `/etc/powerdns` に読み取り専用でマウントされていること

動作確認例:

```
dig @127.0.0.1 mox.si A +short
dig @127.0.0.1 google.com A +short
```
