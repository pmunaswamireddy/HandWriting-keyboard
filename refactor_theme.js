const fs = require('fs');
const path = require('path');

const walkSync = function(dir, filelist) {
  files = fs.readdirSync(dir);
  filelist = filelist || [];
  files.forEach(function(file) {
    if (fs.statSync(dir + '/' + file).isDirectory()) {
      filelist = walkSync(dir + '/' + file, filelist);
    }
    else {
      if (file.endsWith('.dart')) {
          filelist.push(path.join(dir, file));
      }
    }
  });
  return filelist;
};

const files = walkSync('d:/hand keyboard/lib');

for (const file of files) {
  if (file.includes('app_theme.dart')) continue;

  let content = fs.readFileSync(file, 'utf8');
  let original = content;

  content = content.replace(/AppTheme\.surface0/g, 'Theme.of(context).scaffoldBackgroundColor');
  content = content.replace(/AppTheme\.surface1/g, 'Theme.of(context).colorScheme.surface');
  content = content.replace(/AppTheme\.surface2/g, 'Theme.of(context).colorScheme.surfaceContainerHighest');
  content = content.replace(/AppTheme\.surface3/g, 'Theme.of(context).colorScheme.onSurface.withOpacity(0.1)');
  
  if (content !== original) {
    fs.writeFileSync(file, content, 'utf8');
    console.log(`Updated ${file}`);
  }
}
