#!/bin/sh

### 説明 ##################
# cd -nでn個上の親に行く
###########################

# 引数を確認して第一引数の先頭に-があるかを確認
if [[ $# == 1 && ${1:0:1} = "-" ]]; then
  number=${1#-}
  # "cd -0"か"-"ならカレントディレクトリを指す
  if [[ $number == 0 || $number == "" ]]; then
    file_path="./"
  else
  # cd -の時はcd ../と同義とする
    file_path=""
    # 数字の数だけ../を追加する
    for i in $(seq 1 $number); do
      file_path="$file_path../"
    done
  fi
  # cdを直接呼ぶと再帰呼び出しになって無限ループするので、一度文字列化
  command="cd $file_path"
else
  command="cd $@"
fi
# evalがないとcd $@ファイルを探そうとするため。
eval $command