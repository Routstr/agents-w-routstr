cd routstr-openclaw/
tar -czvf routstr-kit-openclaw.tar.gz AGENTS.md openclaw.json skills/
cd ../routstr-lnvps-openclaw/
tar -czvf routstr-kit-lnvps-openclaw.tar.gz AGENTS.md openclaw.json skills/
cd ../
cp lnvps-routstr-openclaw.sh routstr-openclaw.sh routstr-openclaw/routstr-kit-openclaw.tar.gz routstr-lnvps-openclaw/routstr-kit-lnvps-openclaw.tar.gz ../landingpage/public/
cd ../landingpage/
git add *
git commit -m "new cdn files uploaded"
git push origin main
