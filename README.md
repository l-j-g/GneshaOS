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
| `hosts/cf-fv1/` | Machine configuration: `default.nix` + machine-generated `hardware-configuration.nix` |
| `modules/` | Reusable NixOS modules: `btrfs`, `fonts`, `hardening`, `letsnote` |
| `home/` | Home-manager user environment (apps, desktop, editors, fonts, shell, theme) |
| `docs/` | Install runbook |

## Install / usage

```sh
# Build and switch the system
sudo nixos-rebuild switch --flake .#cf-fv1

# Dry-run build
nixos-rebuild build --flake .#cf-fv1
```

The hostname is `cf-fv1` and the username is `lg` by default — both are
configurable in `flake.nix` (`username` is set once, near the top; the host is
the `nixosConfigurations` key).

For a from-scratch install, follow [`docs/install.md`](docs/install.md).

## Notes

- `hosts/cf-fv1/hardware-configuration.nix` is **machine-generated** by
  `nixos-generate-config` — it ships for reference but is not meant to be
  hand-edited.
- `flake.lock` is pinned; run `nix flake update` to bump inputs.
