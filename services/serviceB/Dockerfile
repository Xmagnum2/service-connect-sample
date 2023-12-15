# ベースイメージを指定
FROM golang:1.21

# 作業ディレクトリを設定
WORKDIR /app

# ソースコードをコピー
COPY . .

# コンパイルや実行などのコマンドを実行する場合
# 例えば、main.goをビルドする場合
RUN go build -o main .

# コンテナが起動した時に実行されるコマンド
# 例えば、mainを実行する場合
CMD ["./main"]
