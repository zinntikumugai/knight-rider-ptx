# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

Earthsoft PT3、PLEX PX-Q3PE、PX-BCUD 用の DVB ドライバ。ISDB-S/T 対応の Linux カーネルモジュール。

## ビルドコマンド

```bash
# 通常ビルド
make

# デバッグビルド
make debug

# テスト実行
make test

# インストール（DKMS なし）
make install

# インストール（DKMS あり - 自動アップデート対応）
chmod +x dkms.install dkms.uninstall
./dkms.install

# クリーン
make clean

# アンインストール
make uninstall  # または ./dkms.uninstall
```

## Docker 環境でのビルド（Kernel 6.8.0 対応済み）

このプロジェクトは Kernel 6.8.0 / Ubuntu 24.04 に対応済みです。Docker を使用してビルド・テストできます：

```bash
# Docker イメージのビルド
docker build -t ptx-build .

# コンテナでビルド環境を起動
docker run -it --rm ptx-build

# コンテナ内でビルドとテスト
make clean
make
make test
```

### Kernel 6.8.0 対応修正内容

- `media/dvb_math.h` → `linux/int_log.h` への移行
- i2c_driver の probe/remove 関数シグネチャ変更対応
- 非推奨 DMA API (`pci_alloc_consistent` など) の新 API への移行
- `strlcpy` → `strscpy` への移行
- 関数プロトタイプ警告の修正 (`static` 化)
- pxq3pe_pci.c: I2C 読み込み時のバッファ割り当てサイズ修正（`kzalloc(sz, ...)` → `kzalloc(msg->len, ...)`）とmutex解放処理の修正

## コード品質チェック

```bash
make check  # checkpatch.pl と smatch（インストール済みの場合）を実行
```

## アーキテクチャ

### ディレクトリ構造

- `drivers/media/`: DVB ドライバ本体
  - `dvb-frontends/`: デモジュレータ (tc90522)
  - `tuners/`: チューナードライバ群
  - `pci/ptx/`: PCI ブリッジドライバ (pt3, pxq3pe)
  - `usb/em28xx/`: USB ドライバ (PX-BCUD用)
- `drivers/video/`: キャラクタデバイス版ドライバ（通常は無効）
- `apps/`: ユーティリティツール
  - `dvb/cmds/`: DVB ストリーム解析・操作ツール
  - `cdev/recpt1/`: キャラクタデバイス用録画ツール

### 主要モジュール

| モジュール | チップ | 説明 |
|----------|--------|------|
| tc90522 | TC90522XBG, TC90532XBG | 共通デモジュレータ |
| qm1d1c004x | QM1D1C0042, QM1D1C0045 | ISDB-S チューナー |
| mxl301rf | MxL301RF | ISDB-T チューナー |
| tda2014x | TDA20142 | ISDB-S チューナー (PX-Q3PE) |
| nm131 | NM131, NM130, NM120 | ISDB-T チューナー (PX-Q3PE) |
| pt3 | EP4CGX15BF14C8N | PT3 PCI ブリッジ |
| pxq3pe | ASV5220 | PX-Q3PE PCI-E ブリッジ |

### 開発上の注意点

1. **PX-Q3PE のリセット**: warm boot では検出されないため、必ず電源を完全に切ってから起動する
2. **I2C クライアント**: dvb_frontend の .demodulator_priv と .tuner_priv は i2c_client として扱う
3. **共通処理**: ptx_common.c に DVB サブシステムへの登録処理がまとめられている

## DKMS 設定

`dkms.conf` でモジュールの配置先が定義されている：
- フロントエンド → `/kernel/drivers/media/dvb-frontends`
- チューナー → `/kernel/drivers/media/tuners`
- PCI ドライバ → `/kernel/drivers/media/pci/ptx`

## アプリケーションツール

DVB 版ツール (`apps/dvb/cmds/`):
- `nitdump`, `s2scan`, `tcscan`: チャンネルスキャン
- `dumpts`, `ptsdump`: TS ストリーム解析
- `fixpat`, `fixpcr`: TS ストリーム修正
- `jzap`, `tune`, `tctune`: チューニング

ビルド: `cd apps/dvb/cmds && make`

## CI/CD

### GitHub Actions

`.github/workflows/build-test.yml` で自動ビルドテストが実行されます：

- **トリガー**: push, pull request, 手動実行
- **テスト内容**: Docker コンテナ内でのカーネルモジュールビルド
- **成功判定**: オブジェクトファイル（.o）の生成を確認

注: CI 環境では kernel symbols がないため、最終的なモジュールリンクは失敗する場合がありますが、コンパイル段階の成功をもって合格とします。