#!/bin/bash

# ================================
# 配置区域 - 根据你的需求修改
# ================================
GIT_AUTHOR="liyiyang5"
DAYS_TO_IMPORT=30
DB_PATH="$HOME/Documents/MyDDL/myddl.sqlite"

echo "🚀 Git 提交记录一键导入脚本"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "👤 作者: $GIT_AUTHOR"
echo "📅 天数: $DAYS_TO_IMPORT"
echo ""

# 计算日期
START_DATE=$(date -v-${DAYS_TO_IMPORT}d +%Y-%m-%d)
END_DATE=$(date +%Y-%m-%d)

# 临时文件
SQL_FILE="/tmp/import_commits_$(date +%s).sql"
REPO_LIST="/tmp/repos_$(date +%s).txt"
> "$SQL_FILE"

# 获取仓库列表
sqlite3 "$DB_PATH" "SELECT id, name, path FROM git_repositories WHERE isActive = 1;" > "$REPO_LIST"

TOTAL=0

# 处理每个仓库
while IFS='|' read -r repo_id repo_name repo_path; do
    echo "▶ $repo_name"

    [ ! -d "$repo_path/.git" ] && echo "  ⚠️  跳过（不存在）" && continue

    cd "$repo_path" || continue

    # 获取提交
    git log --all \
        --since="$START_DATE" \
        --until="$END_DATE" \
        --author="$GIT_AUTHOR" \
        --pretty=format:'%H|%an|%ae|%aI|%s' \
        --date=iso-strict 2>/dev/null | while IFS='|' read -r hash author_name author_email date_iso message; do

        # 转换时间戳
        timestamp=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$date_iso" +%s 2>/dev/null)
        [ -z "$timestamp" ] && continue

        # 转义单引号
        hash="${hash//\'/\'\'}"
        author_name="${author_name//\'/\'\'}"
        author_email="${author_email//\'/\'\'}"
        message="${message//\'/\'\'}"

        # 生成 SQL
        cat >> "$SQL_FILE" << SQL
INSERT OR IGNORE INTO git_commits (id, hash, authorName, authorEmail, date, message, repositoryId, createdAt)
VALUES ('$(uuidgen)', '$hash', '$author_name', '$author_email', $timestamp, '$message', '$repo_id', $(date +%s));
SQL
        TOTAL=$((TOTAL + 1))
    done

    COUNT=$(grep -c "INSERT" "$SQL_FILE" 2>/dev/null || echo 0)
    echo "  ✅ $COUNT 条"

done < "$REPO_LIST"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 生成 $(wc -l < "$SQL_FILE" | tr -d ' ') 条 SQL"

# 导入
if [ -s "$SQL_FILE" ]; then
    echo "💾 导入中..."
    sqlite3 "$DB_PATH" < "$SQL_FILE"

    FINAL_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM git_commits;")
    echo "✅ 完成！数据库现有 $FINAL_COUNT 条记录"

    rm -f "$SQL_FILE" "$REPO_LIST"
else
    echo "❌ 没有数据可导入"
    rm -f "$SQL_FILE" "$REPO_LIST"
    exit 1
fi
