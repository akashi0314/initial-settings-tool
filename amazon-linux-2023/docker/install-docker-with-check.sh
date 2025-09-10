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

# ここからインストールチェック
echo ""
echo "==================================="
echo "インストール状態をチェックしています..."
echo "==================================="
echo ""

# チェック結果カウンター
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# 1. Docker コマンドの存在確認
echo "1. Docker コマンドチェック..."
if command -v docker &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Docker コマンドが見つかりました"
    ((PASS_COUNT++))
else
    echo -e "  ${RED}✗${NC} Docker コマンドが見つかりません"
    ((FAIL_COUNT++))
fi

# 2. Docker サービスの状態確認
echo "2. Docker サービス状態チェック..."
if sudo systemctl is-active docker &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Docker サービスが起動しています"
    ((PASS_COUNT++))
else
    echo -e "  ${RED}✗${NC} Docker サービスが起動していません"
    ((FAIL_COUNT++))
fi

if sudo systemctl is-enabled docker &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Docker サービスの自動起動が有効です"
    ((PASS_COUNT++))
else
    echo -e "  ${YELLOW}⚠${NC} Docker サービスの自動起動が無効です"
    ((WARN_COUNT++))
fi

# 3. Docker グループメンバーシップ確認
echo "3. Docker グループ権限チェック..."
if groups $USER | grep -q docker; then
    echo -e "  ${GREEN}✓${NC} ユーザー '$USER' は docker グループに追加されました"
    echo -e "  ${YELLOW}⚠${NC} 注意: グループ権限を反映するには再ログインが必要です${NC}"
    ((PASS_COUNT++))
    ((WARN_COUNT++))
else
    echo -e "  ${RED}✗${NC} ユーザー '$USER' の docker グループ追加に失敗しました"
    ((FAIL_COUNT++))
fi

# 4. Docker Compose チェック（プラグイン版）
echo "4. Docker Compose (プラグイン版) チェック..."
if sudo docker compose version &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Docker Compose プラグインが正常にインストールされました"
    ((PASS_COUNT++))
else
    echo -e "  ${RED}✗${NC} Docker Compose プラグインのインストールに失敗しました"
    ((FAIL_COUNT++))
fi

# 5. Docker Compose チェック（スタンドアロン版）
echo "5. Docker Compose (スタンドアロン版) チェック..."
if command -v docker-compose &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} docker-compose コマンドが使用可能です"
    ((PASS_COUNT++))
else
    echo -e "  ${RED}✗${NC} docker-compose コマンドが見つかりません"
    ((FAIL_COUNT++))
fi

# 6. Docker 基本動作テスト
echo "6. Docker 基本動作テスト..."
if sudo docker run --rm hello-world &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Docker は正常に動作しています"
    ((PASS_COUNT++))
    # クリーンアップ
    sudo docker rmi hello-world &> /dev/null 2>&1 || true
else
    echo -e "  ${RED}✗${NC} Docker の動作テストに失敗しました"
    ((FAIL_COUNT++))
fi

# 7. ディスク容量チェック
echo "7. ディスク容量チェック..."
DOCKER_ROOT=$(sudo docker info 2>/dev/null | grep "Docker Root Dir" | awk '{print $NF}')
if [ -n "$DOCKER_ROOT" ]; then
    DISK_USAGE=$(df -h $DOCKER_ROOT 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
    AVAILABLE=$(df -h $DOCKER_ROOT 2>/dev/null | tail -1 | awk '{print $4}')
    
    if [ -n "$DISK_USAGE" ] && [ "$DISK_USAGE" -lt 80 ]; then
        echo -e "  ${GREEN}✓${NC} 十分なディスク容量があります (利用率: ${DISK_USAGE}%, 空き: ${AVAILABLE})"
        ((PASS_COUNT++))
    elif [ -n "$DISK_USAGE" ]; then
        echo -e "  ${YELLOW}⚠${NC} ディスク容量が少なくなっています (利用率: ${DISK_USAGE}%, 空き: ${AVAILABLE})"
        ((WARN_COUNT++))
    fi
fi

# 結果サマリー
echo ""
echo "==================================="
echo "インストールチェック結果"
echo "==================================="
echo -e "成功: ${GREEN}${PASS_COUNT}${NC} 項目"
echo -e "警告: ${YELLOW}${WARN_COUNT}${NC} 項目"
echo -e "失敗: ${RED}${FAIL_COUNT}${NC} 項目"

if [ $FAIL_COUNT -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Docker は正常にインストールされました！${NC}"
    echo ""
    echo "==================================="
    echo "次のステップ"
    echo "==================================="
    echo ""
    echo "Docker グループの権限を有効にするため、以下のいずれかを実行してください："
    echo ""
    echo "オプション 1: 現在のセッションで有効化（一時的）"
    echo -e "  ${YELLOW}newgrp docker${NC}"
    echo ""
    echo "オプション 2: 再ログイン（恒久的）"
    echo -e "  ${YELLOW}exit${NC} して再度 SSH 接続"
    echo ""
    echo "その後、以下のコマンドで動作確認できます："
    echo -e "  ${BLUE}docker run hello-world${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}❌ インストール中に問題が発生しました${NC}"
    echo "上記のエラーメッセージを確認して、問題を解決してください。"
    echo ""
    echo "トラブルシューティング："
    echo "1. インターネット接続を確認"
    echo "2. sudo 権限があることを確認"
    echo "3. エラーメッセージに従って対処"
    echo ""
    exit 1
fi