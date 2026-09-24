# 🐘 GneshaOS

> NixOS + home-manager configuration, blessed by the elephant.

A declarative NixOS configuration for a [Panasonic Let's Note CF-FV1](https://panasonic.jp/pc/products/letsnote/), running Sway on Wayland with a fully home-managed user environment.

```
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠔⠑⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢘⡤⠤⣜⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠾⠀⠀⠀⠀⠹⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠰⣑⠶⠬⠭⠭⠥⠶⢆⡆⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⡤⠐⠊⠉⢩⢼⡹⢉⠉⠑⠓⠤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡴⣑⠊⠁⠠⡬⠔⢱⡢⠩⠓⣀⠠⠡⢊⢦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⢔⠉⢐⢄⢈⠬⣩⡘⠃⠈⢡⣎⠡⣀⠁⠖⠉⡢⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⢎⠤⡐⡮⡐⢃⡇⠸⡑⠁⠈⢊⠇⢈⡼⠐⣺⢢⠈⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠢⡈⣢⠔⡂⠬⠍⠛⢫⠅⠩⡭⠍⠭⠄⢒⠤⡒⣐⠘⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢀⠶⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠣⢥⠎⢅⠥⠂⠈⠉⠉⠉⠐⠂⠉⠉⠉⠀⠒⢅⡊⣃⠈⡅⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⠀⠶⡀⠀⡄⠀⠀⠀⠀
⠀⠀⢀⢠⡄⢀⣓⣲⡁⠀⠀⠀⢀⠔⠂⠈⠁⠐⠢⢴⡓⣱⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢳⡴⣱⡣⠔⠒⠒⠒⠤⡀⠀⢖⠴⠀⡞⠀⠘⡀⠱⠂⠇⠀⠀
⠀⡜⠁⠐⢄⣰⠄⡺⡠⢄⠀⡔⢁⠄⠊⠉⠉⠁⠢⡌⢻⠇⠀⠊⠉⠐⣄⠀⠀⠦⠴⠀⠀⡴⠊⠐⠒⠌⣷⠏⠠⠂⠈⠁⠐⢤⠈⢆⠘⡀⢄⢧⠀⠀⢃⠇⡜⠀⠀⠀
⠸⠀⠀⠀⣆⡸⢀⠉⡰⡸⠸⡐⠁⠀⠀⠀⠀⠀⠠⢔⡏⠀⠠⣮⣥⣂⠀⠀⠀⠀⠀⠀⠈⢀⣰⡤⠢⠀⢸⣎⠠⠤⠀⠀⠀⠀⠑⠌⡆⡨⠓⡹⠓⠚⡷⣉⠩⠓⠀⠀
⠀⠣⣰⠁⠀⠇⡜⢏⡠⠁⠀⠀⡆⠀⠀⠀⠀⠀⠄⠀⡇⠀⠀⠙⠉⠘⠀⠀⠀⠀⠀⠀⠀⠸⠛⠃⠁⠀⢸⠀⠀⠄⠀⠀⠀⠀⢠⠊⠁⠃⠁⠀⠉⠹⠀⠀⠀⠀⠀⠀
⠀⠀⠀⡤⣼⠉⠁⠀⠀⠀⠀⠀⠸⡀⠀⠀⠀⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠠⠄⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠀⠀⠀⠀⠇⠀⠀⠀⠀⠀⢠⢧⠋⢙⠀⠀⠀⠀
⠀⡰⡉⢣⠈⠀⢣⠀⠀⠀⠀⠀⠀⠑⢄⠀⠀⠀⠀⠀⢰⡀⠀⢀⡀⡐⠀⠀⠀⠀⠐⠀⠀⠀⡄⠀⠀⠀⡄⠀⠀⠀⠀⠀⢀⠌⠀⠀⠀⠀⠀⢠⠁⡞⡒⢁⠼⢄⠀⠀
⠔⠢⡘⣄⠏⠄⠀⡆⠀⠀⠀⠀⠀⠀⠀⢡⠀⠀⢀⠠⢂⢗⣄⠘⡤⠁⠀⠀⠀⠀⠀⠀⠀⠀⢑⡄⡠⢎⢃⠀⠀⠀⢀⠔⠁⠀⠀⠀⠀⠀⠀⡇⠀⢸⣤⡂⡔⠊⠂⠀
⠈⠁⠋⡏⠀⠀⢀⠀⠀⠀⠀⡀⡀⠀⠀⣸⠀⠤⠐⠺⠩⢜⣧⠽⠉⢰⠀⠀⠀⠀⠀⠀⠀⢷⠁⠹⡸⠭⠴⣅⡀⠀⠠⢀⠀⠀⠀⠀⠀⠀⠀⢱⠀⠀⠈⡝⢅⢃⠇⠀
⠸⡀⠀⠃⠀⠠⣎⠀⢀⣰⠉⠀⠋⢡⠊⠀⠀⠀⠀⢰⢨⢡⢂⢇⠈⢱⠀⠀⠀⠀⠀⠀⢰⠁⢑⢲⠎⡩⠁⡇⠀⠉⠁⠀⠙⢆⠀⠀⠀⠀⠀⣠⢷⠀⠀⠁⠈⣎⠄⠀
⠀⡷⠆⠀⠤⡂⢊⡇⡎⢸⠀⠀⢈⢸⢀⣀⠀⡄⠀⠈⠆⣊⢏⠷⡢⢸⠀⠀⠀⠀⠀⠀⠘⣔⡡⢏⠁⡱⠱⠀⠀⠀⡀⠀⠀⠀⢣⠀⠀⠀⡠⠦⡢⠑⣢⠤⢞⡌⠋⡆
⠀⢫⠤⠬⠕⠂⠁⠈⠁⢸⣀⡄⠸⠀⡏⢰⢱⠀⠀⠀⠈⢆⢞⡸⡬⣑⢆⠀⠀⠀⠀⠀⠀⠱⡜⡌⡖⡑⠁⠀⠀⠀⠇⠀⠀⠀⡸⢱⢀⠔⠁⠀⠈⠀⠒⠛⡒⠀⠀⠀
⠀⠐⡄⠀⠀⠀⠀⢠⠀⠉⠀⠀⢀⠤⠁⠘⣼⠀⠀⠀⠀⠀⢊⢂⢳⠀⠈⠢⡀⠀⠀⠀⠀⠀⠘⡜⠌⠀⠀⠀⠀⠀⡆⠀⠀⡰⢡⠧⢣⠀⠀⠀⠀⠀⠀⢠⠁⠀⠀⠀
⠀⠀⢇⠀⠀⠀⠀⠀⠀⠀⠀⢀⠁⠀⠀⢀⡇⠇⠀⠀⡀⠀⠀⡌⣁⡄⠀⠀⠸⠉⠠⡀⠀⠀⠀⠹⠀⠀⡀⠀⠀⢠⣁⠠⢈⠄⢹⡀⣄⡄⠀⠀⠀⠀⠀⡈⠀⠀⠀⠀
⠀⠀⠈⢄⠀⠀⠀⡰⣇⠀⠀⠸⠀⠀⢀⡜⠔⡌⠂⠄⠉⡀⠀⠠⡇⠇⠀⡌⠀⠰⠤⠞⠀⠀⢀⡇⣀⡒⣁⡀⠴⡚⢀⠜⡉⠬⠐⠪⠤⣇⡀⠀⠀⠀⡰⠁⠀⠀⠀⠀
⠀⠀⠀⠈⠦⡀⢠⠱⠣⡣⢒⣀⣀⠲⡙⡅⢸⠇⠀⠀⠀⠀⠀⠰⡇⢅⠀⠐⣀⠀⠀⠀⠀⣠⡎⡄⠀⠀⠀⠀⠀⢧⠢⠋⡀⠤⠤⢄⣰⠁⠈⡆⢀⠴⠁⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠉⢎⠀⠁⠪⠄⠀⠀⠬⠊⣰⠏⠀⠀⠀⠀⠀⠀⢰⢱⣘⡀⠀⠀⠉⠀⠈⢁⠥⢢⠀⠀⠀⠀⠀⠀⠈⢦⠊⠀⣀⠰⡁⠀⡱⢎⠀⢀⠦⣀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠘⡀⠀⠀⠀⠀⠀⠀⠠⡏⠀⠀⠀⠀⠀⠀⠀⠈⢆⢆⢑⢄⣀⣀⡀⢤⢫⢍⠎⠀⠀⠀⠀⠀⠀⠀⠸⣠⣴⠁⠀⢈⠊⠀⠀⢱⠁⠀⠈⣤⡀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠘⠢⢀⣀⡀⠤⠂⠁⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠢⢅⡒⣤⢤⠧⣈⠥⠊⠀⠀⠀⠀⠀⠀⠀⠀⢠⠱⢞⠩⠥⠬⠥⣄⡠⡮⡴⡬⠍⠳⣅⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⢀⣀⡤⠤⢔⣀⠺⢯⡵⡑⢄⠀⠀⠀⠀⠀⠀⠀⠀⠀⡌⢔⠢⠡⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡠⠺⣧⢘⠲⠤⡔⠒⠁⢹⠀⡎⠀⠶⠥⠊⠀⠀⠀
⠀⠀⠀⠀⢀⠔⠊⠁⠀⠀⠈⠑⠂⢌⠢⡙⢮⡂⠕⠢⢄⠀⠀⠀⠀⠀⠀⠈⠒⠒⠁⠀⠀⠀⠀⠀⠀⠀⡠⠔⡪⢜⡟⠤⠙⠚⣤⣥⣜⣠⣃⣴⠤⠚⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢠⠃⠀⠀⠀⠀⠀⠀⠁⠀⠉⠉⠚⠪⢎⠂⠌⡂⠠⢍⡒⠀⠠⠤⠤⠄⡀⠠⠤⠤⠄⠀⣒⠩⠄⢒⡡⠈⡡⠐⢊⣁⣀⣀⡀⠀⠉⠂⠀⠈⠂⡀⠀⠀⠀⠀⠀
⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠢⢄⠉⠒⠀⠠⠤⢽⣉⡏⡍⣣⣉⣉⠠⠤⠀⡲⢫⡬⠄⠚⠉⠉⠉⠈⠁⠂⠀⠀⠀⠀⠀⠀⠀⠘⡄⠀⠀⠀⠀
⠀⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠊⠙⣦⠤⡤⠄⢒⡵⠗⠉⡑⢍⣉⣉⣥⠴⡚⠃⠠⢀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡥⠀⠀⠀⠀
⠀⠀⠀⢱⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠔⠁⢠⠢⢁⠀⠱⢩⢲⡮⢠⠒⠓⠫⣕⢠⠘⢕⢄⠑⢄⠀⠈⠁⠐⠒⠒⠂⠀⠀⠀⠀⠀⠀⠀⠀⠀⡅⠀⠀⠀⠀
⠀⠀⠀⠀⠣⠀⠢⡀⠀⠈⠒⠤⠤⠤⠤⠒⠈⠀⠀⡠⡂⠃⡈⠀⡘⡐⡘⢰⠀⠑⡀⠀⠈⡄⠱⡀⢂⠡⡀⠑⠤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡰⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠑⣑⢌⠐⠄⢀⡀⠀⠀⠀⣀⠠⢔⠨⠊⠀⠐⠁⠠⡁⢡⠁⠎⠀⠀⡇⠀⠰⡏⡄⠱⡀⠡⡈⠢⡀⠈⠁⠒⠠⠤⠤⠄⠒⠀⠀⠀⢀⠜⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠈⣲⣑⠤⣄⡀⠉⢉⡃⠀⠈⠀⢀⠠⠊⢀⢔⠅⢑⠡⠊⠀⠀⠀⢣⠀⠀⠰⠈⢄⠐⢄⠀⠢⡈⠁⠢⠤⠀⠀⠠⠄⠀⠀⡀⠔⠁⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢎⠒⢨⠋⠀⠴⢀⢀⣧⡔⣂⣈⠁⠠⠒⡁⠕⠈⠹⠀⠀⠀⠀⠀⢸⠀⠀⠀⢳⠄⢑⣠⣁⠒⠤⢁⡐⠢⡤⠤⠤⠒⠂⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢀⡠⠗⠀⠀⠀⢀⠄⠉⠀⠀⠈⠉⠀⠉⠓⠒⠐⠀⡝⠄⠆⠀⣃⠀⢪⠀⠢⢠⠙⠀⠀⠀⠀⠈⠉⠁⢀⠔⠉⢢⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢀⠔⠁⠀⠀⠀⠀⡀⣜⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠚⠶⠤⢅⠥⠊⠣⠭⠋⠀⠀⠀⠀⠀⠀⡠⠒⢆⠀⡤⣀⠗⠙⢠⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⡎⠀⠀⠀⠂⢄⠠⣈⠩⢕⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠔⢎⠀⢀⣠⠃⠀⠈⢂⢄⢀⠗⠢⡀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⡇⠀⠀⠀⠀⢀⢀⠎⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⠄⢲⠁⠀⢀⡕⠁⠈⠑⣄⠔⠁⠀⠙⡄⠀⠘⠀⠤⠀⠀⠀⠀⠀⠀
⢀⢄⡲⠍⠤⣀⡀⠠⠾⢯⣝⠑⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⢆⠬⢖⣂⡸⠤⠤⠤⠤⠼⠤⠤⠤⠤⠊⣐⡚⢥⠔⠀⠀⠀⠀⠀⠀
⠆⡇⠀⠀⠀⠀⠀⠀⠀⠈⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠒⠂⠤⠤⢄⣈⣈⣁⣁⣀⠤⠤⠄⠐⠊⠀⠀⠀⠀⠀⠀⠀⠀
⠈⠚⠡⠖⠶⠒⠦⠴⠲⠤⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
```

## Features

- **btrfs + LUKS2 + TPM2 auto-unlock** — root is LUKS2-encrypted on btrfs subvolumes (`@`, `@nix`, `@home`); the firmware TPM (Intel PTT) unlocks it automatically at boot — no passphrase prompt.
- **Home-manager** — the entire user environment (shell, editors, Sway/waybar/swaylock, fonts, theme, daemons) is declared in `home/` and built with the system.
- **Sway / Wayland** — tiling WM with custom bindings, scripts, and a 3:2 QHD panel configured for 200% scaling.
- **`letsnote` module** — Panasonic-specific power management: EC charge-limit / eco mode (`ecFeatures`), optional `panafanpwr` fan control (`fanControl`, CF-FV1 not yet supported — enable at your own risk), and keyd remapping of the dead JIS keys (`jisKeys`).
- **Hardening module** — sshd hardening, locked-down defaults, no default passwords.
- **Nix colors** — theme driven by [nix-colors](https://github.com/Misterio77/nix-colors).

## Repo layout

| Path | Contents |
| --- | --- |
| `hosts/` | One directory per NixOS host; real directories become `nixosConfigurations.<name>` and `homeConfigurations.<user>@<host>`, while `_template/` is excluded |
| `hosts/cf-fv1/` | Panasonic CF-FV1 composition, split by responsibility, plus machine-generated `hardware-configuration.nix` |
| `modules/` | Reusable NixOS modules: `btrfs`, `fonts`, `hardening`, `letsnote` |
| `home/` | Shared Home Manager environment (programs, desktop, editors, shell, theme) |
| `system-parameters.nix` | Stable machine, account, hardware, and path parameters |
| `system-parameters.example.nix` | Documented system-parameter template / fallback |
| `home/variables.nix` | **Editable Home Manager preferences** — theme, gaps, fonts, and desktop behavior |
| `docs/user-parameters.md` | **Full self-service reference** — every parameter, allowed values, quickstart |
| `docs/` | Development workflow, parameter reference, and install runbook |

## Install / usage

```sh
# 1. (First time only) personalise the stable system parameters
cp system-parameters.example.nix system-parameters.nix
#    ... change userName, homeDirectory, timezone, hardware paths, and display
#    identity. Then tune Home Manager preferences in home/variables.nix.

# 2. Add or choose a host. Existing hosts are listed with:
nix eval .#nixosConfigurations --apply builtins.attrNames

# 3. Build and switch the system layer
sudo nixos-rebuild switch --flake .#<host-directory-name>

# 4. Activate the user layer (desktop, shell, theme, and user services)
nh home switch . -c <user>@<host-directory-name>

# Dry-run system build
nixos-rebuild build --flake .#<host-directory-name>
```

System changes use `nixos-rebuild`; user-environment changes use the faster
standalone Home Manager output. The bundled `rebuild` helper runs both layers
in sequence, while `home-rebuild` activates only Home Manager. The theme
picker starts the latter activation in the background after a theme is
accepted.

`system-parameters.nix` is the tracked machine parameter file — account
identity, hardware, stable paths, and host settings. The host directory name is
authoritative for the flake output and is overlaid into that host's
`systemSettings.hostName`. [`docs/user-parameters.md`](docs/user-parameters.md)
is the full self-service reference. To add a machine, copy
[`hosts/_template/`](hosts/_template/), generate its hardware configuration,
and add host-specific imports/settings. The flake discovers the new directory
automatically.

`system-parameters.example.nix` is the documented fallback if
`system-parameters.nix` is missing, so a fresh clone still evaluates. Keep both
system-parameter files tracked: Git flakes do not include ignored or untracked
files.

For a from-scratch install, follow [`docs/install.md`](docs/install.md).
For safe editing and build-only validation, follow
[`docs/development.md`](docs/development.md).

## Notes

- Prefer existing, verified NixOS/Home Manager modules and packages for desktop
  behavior. Keep configuration modules declarative and compact; avoid embedding
  long shell programs or polling daemons in `.nix` files. Only add a focused
  script under the owning layer (for example, `home/programs/scripts/` or
  `home/desktop/sway/scripts/`) when no suitable packaged alternative exists,
  and document the reason alongside the change.
- `hosts/cf-fv1/hardware-configuration.nix` is **machine-generated** by
  `nixos-generate-config` — it ships for reference but is not meant to be
  hand-edited.
- `flake.lock` is pinned; run `nix flake update` to bump inputs.
