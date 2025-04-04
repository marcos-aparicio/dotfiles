# My dotfiles

Repository of my personal config dotfiles organized using stow


- Picom (compositor)
- AwesomeWM (window manager)
- Neovim (editor)
- LF (file manager)
- Rofi (selector?)
- ZSH (shell)
- Alacritty (terminal emulator)
- and much more

### Installation

```bash

git clone https://github.com/marcos-aparicio/dotfiles.git
```

The good thing about using stow is that each folder in the root directory is its own package, you can choose whether to "install" one of the packages into your system or all of them if you want

#### All packages

```bash
# is important to follow exactly that
# if */ then it will also consider the .git directory
# if * then it will also consider files
# i believe this isn't an issue on Ubuntu computers but it is on Arch for some reason
stow -vSt ~ [^.]*/
```


### Single package

```
stow -vSt ~ <directory-name>
```


### Future tasks

- [ ] Have contexts for each program. For example, neovim for `work` or `personal`
- [ ] Adding documentation on helpers of this repository(i.e: justfile)
