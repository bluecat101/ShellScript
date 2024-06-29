#!/bin/sh

## README ####################################################################
# 説明(git pull -d )
# git pull -dとはgit pullをしつつ、任意のブランチがリモートブランチに存在せず、リモート追跡ブランチが存在するときに、リモート追跡ブランチとローカルブランチを削除するオプションです。
# つまり、git fetch -pに対してローカルブランチまで消すオプションです。
# ---注意点---
# リモートリポジトリの名称は一般的あるoriginである必要があります。(複数名称がある場合に処理が大変だったため拡張性を消しています。)
# リモートブランチの名前とローカルブランチの名前は同じである必要があります。(ローカルブランチがどのリモートブランチと紐づいているのかを取得できる方法はありますが、大変であるため今回は同じ名前に限定しています。)

# 説明(git apply -l)
# git applyでDownloadsから最新のpatchファイルを取ってくるコマンドです。
# ---注意点---
# $HOME(ホームディレクトリ)の直下にDownloadsがあること(日本語で「ダウンロード」はNG)
# pathファイルもダウンロードにあること
# "git apply -l　ファイル名"等のように使うとエラーが出ます。-lのみで使用します。

# 説明(git diff -patch)
# git diff > ファイル名を"日付.patch"で自動生成。Downloadsディレクトリに保存される
# ---注意点---
# $HOME(ホームディレクトリ)の直下にDownloadsがあること(日本語で「ダウンロード」はNG)
##############################################################################

### 作成する関数 ###
pull_delete(){
  # 初期設定
  remote_branch_name="remotes/origin/"

  post_branch=$(git branch -a)
  git fetch -p >/dev/null
  current_branch=$(git branch -a)
  for post_b in ${post_branch[@]}; do
    # remotes/origin/HEADに対応するHEADブランチは基本的に存在しないため
    if [[ "$post_b" == "remotes/origin/HEAD" ]]; then
      continue
    # remotes/branchが消されたのかを確認するので、ブランチの名前に"remotes/origin/"がつかないものは探索しなくて良いので抜ける
    elif [[ ! "$post_b" == *${remote_branch_name}* ]]; then
      continue
    fi

    has_branch=false
    # "remotes/origin/"の付くブランチが消されたかを確認する
    for currnet_b in ${current_branch[@]}; do
      if [[ $post_b == $currnet_b ]]; then
        has_branch=true
      fi
    done
    # ローカルブランチの削除
    if ! $has_branch ; then
      git branch -D ${post_b##$remote_branch_name}
    fi
  done
}

apply_latest(){
  # findコマンドで全てのpatchファイルを取得してそこからls -ltで時系列順に並べて最初の項(最新のファイル)のみに対して表示されている一番後ろの要素であるパス名を取得する
  file_path=$(find $HOME/Downloads/ -name "*.patch" -print0| xargs -0 ls -lt | head -1 | awk '{print $NF}')
  # 最後にRE_COMMAND(git apply)を表示するので、そこにファイルパスを追加しておく。
  RE_COMMAND=$RE_COMMAND" "$file_path
}

diff_get_patch_file(){
  # 日付からpatchファイルを作成。同名のpatchファイルがある場合には上書きされる。
  date=$(date "+%m%d")
  file_path=$HOME"/Downloads/"$date".patch"
  # 最後にRE_COMMAND(git diff)を実行するので、そこにファイルパスを追加しておく。
  RE_COMMAND=$RE_COMMAND" > "$file_path
}



### 実行のメイン部分 ###
# 何のgitのコマンドが使われたかを取得
if [[ $# > 1 ]]; then
  GIT_COMMAND=$1
fi

# 再度gitコマンドを呼び出す用(追加したオプションを一緒に呼び出すと「そんなオプションはない」とエラーになるので、追加したオプションのみを消してコマンドを再構成)
RE_COMMAND="git"
# getoptsでoptionを取得できるが、どこに追加したオプション用の引数があるか位置特定できないので、引数をfor文で全部見ていく
for arg in "$@"
do
  # case文の中に他の追加したオプションも追加していくことで使用可能
  case $GIT_COMMAND in
    pull )
      # 追加したいオプションが複数ある時は|で繋げる
      # 追加オプションごとに分けると１つの引数に複数の追加オプションがあったときにループ内で戻ってこれないため、一括で管理している。
      target_option="d" 
      # 最初の正規表現で先頭に-が1つしかないオプションのみに対応している
      if [[ $arg =~ ^-[^-]+ && $arg =~ "$target_option" ]]; then
        ## 複数ある場合にはここに追加
        if [[ $arg == *"d"* ]]; then
          pull_delete
        fi
        # 使用した追加オプションを消す。//を使ったパラメータ展開では動作しなかったためsedを使用。
        # 追加オプションを消した後に他のオプションが残っていれば、コマンドの再実行の時に使用するので、argにセットする。
        deleted_opt=$(echo "$arg" | sed -E "s/$target_option//g")
        if [ $deleted_opt != "-" ]; then
          arg=$deleted_opt
        else
          continue
        fi
      fi
      ;;
    apply )
      target_option="l"
      if [[ $arg =~ ^-[^-]+ && $arg =~ "$target_option" ]]; then
        apply_latest
        deleted_opt=$(echo "$arg" | sed -E "s/$target_option//g")
        if [ $deleted_opt != "-" ]; then
          arg=$deleted_opt
        else
          continue
        fi
      fi
      ;;
    diff )
      target_option="patch"
      if [[ $arg =~ ^-[^-]+ && $arg =~ "$target_option" ]]; then
        diff_get_patch_file
        deleted_opt=$(echo "$arg" | sed -E "s/$target_option//g")
        if [ $deleted_opt != "-" ]; then
          arg=$deleted_opt
        else
          continue
        fi
      fi
      ;;
  esac
  # 再度コマンドを実行する用にコマンドを再構築
  RE_COMMAND=$RE_COMMAND" "$arg
done 

# 追加オプションを消したコマンドを再実行。(">")を使用する場合があるので、evalを使っている。)
eval $RE_COMMAND
