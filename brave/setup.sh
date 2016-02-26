[[ -e setup.sh  ]] || { echo 'setup.sh must be run from brave directory'; exit 1; }

# Pro Tip for ad-hoc building: add your app id as an arg, like ./setup.sh org.foo.myapp

app_id=${1:-com.brave.ios.browser}
echo CUSTOM_BUNDLE_ID=$app_id > xcconfig/.bundle-id.xcconfig
if [  -z $1 ] ; then
  echo DevelopmentTeam = KL8N8XSYF4 >> xcconfig/.bundle-id.xcconfig
fi

sed -e "s/BUNDLE_ID_PLACEHOLDER/$app_id/" Brave.entitlements.template > Brave.entitlements

# Replace the removed xcconfigs with ours
(cd ../Client && rm -rf Configuration &&  ln -sfn ../brave/xcconfig Configuration)

npm update

#output a placeholder id, Archive builds will generate a real build id
echo GENERATED_BUILD_ID=1  > xcconfig/build-id.xcconfig
## cp xcconfig/build-id.xcconfig ../Client/Configuration

#create the xcode project
python brave-proj.py 

echo ""
echo "If files are added/removed from the project, regenerate it with ./brave-proj.py"
echo "Consider adding the post-checkout script for git automation (instructions are in that file)"
