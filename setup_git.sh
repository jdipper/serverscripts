sudo yum -y install git

echo "Please specify your name:"
read name
echo "Please specify your email address (or GitHub email alias):"
read alias
echo "Please specify your email address used to log in to GitHub:"
read email
echo "Please specify a file in which to save the key ($HOME/.ssh/idrsa):"
read file

if [[ $file == "" ]]; then
  file="$HOME/.ssh/idrsa"
fi

git config --global user.name "$name" 
git config --global user.email "$alias" 
ssh-keygen -t rsa -b 4096 -C $email -f $file

echo "Set up complete.  Please copy and paste your public key below into your GitHub account:"
cat $HOME/.ssh/idrsa.pub
