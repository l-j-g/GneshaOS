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
| `hosts/cf-fv1/` | Machine configuration: `default.nix` + machine-generated `hardware-configuration.nix` (the only file with machine-specific values — disk UUIDs — and intentionally not parameterised) |
| `modules/` | Reusable NixOS modules: `btrfs`, `fonts`, `hardening`, `letsnote` |
| `home/` | Home-manager user environment (apps, desktop, editors, fonts, shell, theme) |
| `params.nix` | **Top-level user parameters** — edit this one file to make the config yours |
| `params.example.nix` | Documented template / fallback (same values as `params.nix`) |
| `docs/` | Install runbook |

## Install / usage

```sh
# 1. (First time only) personalise the top-level parameters
cp params.example.nix params.nix   # or just edit params.nix directly
#    ... change userName, gitUserEmail, hostName, timeZone, displayWidth/Height,
#    displayScale, keyboardLayout ... every user-facing value lives here.

# 2. Build and switch the system
sudo nixos-rebuild switch --flake .#<hostName from params.nix>

# Dry-run build
nixos-rebuild build --flake .#<hostName from params.nix>
```

`params.nix` is the single top-level parameter file — username, hostname,
display resolution/scaling, keyboard layout, timezone, paths and preferences.
It is tracked by design (git flakes only see tracked files), so fork it and
make it yours. [`params.example.nix`](params.example.nix) documents every
variable with allowed/example values and is also the fallback if `params.nix`
is ever missing, so a fresh clone always evaluates.

For a from-scratch install, follow [`docs/install.md`](docs/install.md).

## Notes

- `hosts/cf-fv1/hardware-configuration.nix` is **machine-generated** by
  `nixos-generate-config` — it ships for reference but is not meant to be
  hand-edited.
- `flake.lock` is pinned; run `nix flake update` to bump inputs.
