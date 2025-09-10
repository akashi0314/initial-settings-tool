#!/bin/bash
# EC2 (Amazon Linux 2023) 初期設定用
# Docker & Docker Compose インストールスクリプト（チェック機能付き）
set -e

# 色付き出力用の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "==================================="
echo "Docker と Docker Compose をインストールします"
echo "==================================="

# システムアップデート
echo -e "${BLUE}システムをアップデート中...${NC}"
sudo yum update -y

# Docker インストール
echo -e "${BLUE}Docker をインストール中...${NC}"
sudo yum install -y docker

# Docker サービス開始・自動起動設定
echo -e "${BLUE}Docker サービスを設定中...${NC}"
sudo systemctl start docker
sudo systemctl enable docker

# 現在のユーザーを docker グループに追加
echo -e "${BLUE}ユーザー権限を設定中...${NC}"
sudo usermod -aG docker $USER

# Docker Compose インストール
echo -e "${BLUE}Docker Compose をインストール中...${NC}"

# アーキテクチャを自動検出
ARCH=$(uname -m)
case $ARCH in
    x86_64) COMPOSE_ARCH="x86_64" ;;
    aarch64) COMPOSE_ARCH="aarch64" ;;
    *) echo -e "${RED}サポートされていないアーキテクチャ: $ARCH${NC}"; exit 1 ;;
esac

# Docker Compose の最新バージョンを取得
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
if [ -z "$COMPOSE_VERSION" ]; then
    echo -e "${YELLOW}警告: 最新バージョンの取得に失敗しました。デフォルトバージョンを使用します。${NC}"
    COMPOSE_VERSION="v2.24.0"
fi

echo "Docker Compose ${COMPOSE_VERSION} をダウンロード中..."

# プラグインディレクトリ作成
sudo mkdir -p /usr/local/lib/docker/cli-plugins

# Docker Compose ダウンロード
sudo curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose

# 実行権限付与
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# docker-compose コマンドも使えるようにする
sudo ln -sf /usr/local/lib/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose

echo ""
echo "==================================="
echo -e "${GREEN}インストール完了！${NC}"
echo "==================================="
docker --version
docker compose version

# インストール確認
echo ""
echo "==================================="
echo "インストール確認中..."
echo "==================================="

# 基本チェック
check_result="OK"

echo -n "Docker コマンド: "
if command -v docker >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}NG${NC}"
    check_result="NG"
fi

echo -n "Docker サービス: "
if sudo systemctl is-active docker >/dev/null 2>&1; then
    echo -e "${GREEN}起動中${NC}"
else
    echo -e "${RED}停止中${NC}"
    check_result="NG"
fi

echo -n "Docker Compose: "
if sudo docker compose version >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}NG${NC}"
    check_result="NG"
fi

echo -n "動作テスト: "
if sudo docker run --rm hello-world >/dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
    sudo docker rmi hello-world >/dev/null 2>&1 || true
else
    echo -e "${RED}NG${NC}"
    check_result="NG"
fi

echo ""
if [ "$check_result" = "OK" ]; then
    echo -e "${GREEN}✅ インストール完了！${NC}"
    echo ""
    echo "次のステップ："
    echo -e "1. ${YELLOW}newgrp docker${NC} または再ログインしてグループ権限を有効化"
    echo -e "2. ${BLUE}docker run hello-world${NC} で動作確認"
else
    echo -e "${RED}❌ インストールに問題があります${NC}"
    echo "エラーを確認して再度実行してください。"
    exit 1
fi