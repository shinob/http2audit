# http2audit

HTTP/2 Bomb（CVE-2026-49975）の影響有無を診断し、改善策を提案する Bash スクリプトです。

nginx / Apache / Envoy の設定を静的解析し、OOM ログの痕跡も確認します。

## 使い方

```bash
chmod +x http2audit.sh

# ローカルのサーバー設定のみ診断
./http2audit.sh

# 外部 URL の HTTP/2 有効確認も含めて診断
./http2audit.sh https://example.com

# 結果をファイルに保存
./http2audit.sh --report /tmp/http2audit.txt https://example.com
```

## 出力例

```
=== http2audit: HTTP/2 Bomb 影響診断 ===
実行日時: 2026-06-07 12:00:00

--- STEP 1: 依存コマンド確認 ---
[OK]   curl curl 8.4.0

--- STEP 2: HTTP/2 有効確認 ---
[WARN] https://example.com は HTTP/2 を受け付けています

--- STEP 4: nginx 設定確認 ---
[INFO] nginx/1.24.0 を検出
[WARN] http2_max_concurrent_streams が未設定（デフォルト: 128）→ 64 以下を推奨
[WARN] large_client_header_buffers が未設定（推奨: 4 8k）
[OK]   client_header_timeout = 10s

--- STEP 6: 改善提案 ---
  nginx 推奨設定 (/etc/nginx/nginx.conf の http{} ブロック):
  http {
      http2_max_concurrent_streams 64;
      large_client_header_buffers 4 8k;
      client_header_timeout 10s;
      keepalive_timeout 15s;
  }
  → nginx -t && systemctl reload nginx

=== サマリー ===
[OK]: 3  [WARN]: 2  [INFO]: 1  [SKIP]: 2
```

## 確認内容

| ステップ | 内容 |
|---|---|
| STEP 1 | `curl` の存在確認 |
| STEP 2 | 指定 URL の HTTP/2 有効確認（URL 指定時のみ） |
| STEP 4 | nginx / Apache / Envoy の HTTP/2 関連設定の診断 |
| STEP 5 | OOM・メモリ異常ログの痕跡確認 |
| STEP 6 | 警告項目の改善提案 |

## nginx チェック項目

| 設定 | 推奨値 |
|---|---|
| `http2_max_concurrent_streams` | 64 以下（HTTP/2 が無効な場合は評価対象外） |
| `large_client_header_buffers` | `4 8k` |
| `client_header_timeout` | 10s 以下 |
| `keepalive_timeout` | 15s 以下 |

> `http2_max_concurrent_streams` は `ngx_http_v2_module`（HTTP/2 専用）のディレクティブです。
> HTTP/2 が無効なサーバーではこの設定値自体が nginx に評価されないため、未設定でも
> `[WARN]` ではなく `[SKIP]`（評価対象外）として表示されます。
> 一方、`large_client_header_buffers` / `client_header_timeout` / `keepalive_timeout` は
> HTTP/1.x にも適用される一般的なハードニング設定のため、HTTP/2 の有効・無効に関わらず
> 確認・推奨値への調整をおすすめします。

## Apache チェック項目

| 設定 | 推奨値 |
|---|---|
| `H2MaxSessionStreams` | 50 以下 |
| `H2StreamMaxMemSize` | 65536 以下 |
| `LimitRequestFields` | 50 以下 |

## Envoy チェック項目

| 設定 | 推奨値 |
|---|---|
| `http2_options.max_concurrent_streams` | 100 以下 |
| `max_request_headers_kb` | 60 以下 |

## Webサーバーのバイナリ検出について

nginx / Apache / Envoy は、まず `$PATH` 上で検索し、見つからない場合は
`/usr/sbin`、`/usr/local/sbin`、`/usr/local/nginx/sbin`、`/opt/homebrew/...`（macOS/Homebrew）
など、一般ユーザーの `$PATH` に含まれないことが多い設置場所も自動的に探索します。

それでも見つからない場合は `[SKIP]` と表示されますが、実際にはサーバーが
別の場所にインストールされていることもあります。その場合は環境変数で
バイナリのフルパスを直接指定できます。

```bash
NGINX_BIN=/path/to/nginx ./http2audit.sh https://example.com
APACHE_BIN=/path/to/apachectl ./http2audit.sh https://example.com
HTTPD_BIN=/path/to/httpd ./http2audit.sh https://example.com
ENVOY_BIN=/path/to/envoy ./http2audit.sh https://example.com
```

## テスト

追加インストール不要（Bash のみで動作）。

```bash
# テスト実行
bash tests/run_all.sh
```

## 注意

CVE-2026-49975 は調査時点で NVD に未登録のため、本スクリプトは「HTTP/2 DoS リスク全般の診断ツール」として位置づけています。
正式なベンダーアドバイザリやリリースノートで最新情報を確認してください。

## 参考

- [CVE-2026-49975 解説（Zenn）](https://zenn.dev/long910/articles/2026-06-05-cve-2026-49975-http2-bomb-ai)
- [nginx ngx_http_v2_module](https://nginx.org/en/docs/http/ngx_http_v2_module.html)
- [Apache mod_http2](https://httpd.apache.org/docs/current/mod/mod_http2.html)
- [RFC 9113 - HTTP/2](https://datatracker.ietf.org/doc/html/rfc9113)