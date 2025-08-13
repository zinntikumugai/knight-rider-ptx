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

## Docker 環境でのビルド（Kernel 5.10.33）

このプロジェクトは Kernel 5.10.33 までの対応です。Docker を使用して対応カーネル環境でビルド・テストできます：

```bash
# Docker イメージのビルド
docker build -t ptx-build .

# コンテナでビルド環境を起動
docker run -it --rm -v $(pwd):/opt/knight-rider-ptx ptx-build

# コンテナ内でビルドとテスト
make clean
make
make test
```

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