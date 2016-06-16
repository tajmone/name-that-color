Name That Color
===============

A command line tool that returns the color name of an Hex or RGB color value.

ntc is a free open source utility developed in PureBASIC (v5.42) by Tristano Ajmone in June 2016, and released under the [MIT License](LICENSE).

-   Ready to use [binary for Windows 64bit available in release](https://github.com/tajmone/name-that-color/releases/latest).

> NOTE: I might get around to publish also binaries for Windows 32bit and Linux. In the meantime, if you can help, clone the repo and release binaries for other OSs’ (especially Mac, which I don’t have access to!) for the benefit of those who don’t have PureBASIC.

Description
-----------

Graphics designers and web developers often need to find names for the colors they handle. Naming colors allows better communication between team members and with clients, especially when it boils down to chosing between similar colors. The problem is that there are thousands of color names out there, and most people only need to master a couple of hundred color names to cope with daily life. So, how can we name all those exotic hues, tints and shades we come across during our work?

Name That Color comes to our rescue: it accepts a color definition (hexadecimal or RGB) as input, and spits out the color name that resembles it most from a list of 1566 color name/value pairs.

It’s as simple as this:

    $ ntc #ff4020
    Pomegranate
    $ ntc 120,80,200 
    Fuchsia Blue

Ntc was designed keeping in mind how most people would use it in everyday situations. Its basic mode of operation is to simply receive a color value and return a name for it. Further options are available, for more accurate uses, up to scripted automation employment.

Full documentation available inside the binary file, just type `ntc -h`.

Bulding The Sources
-------------------

You’ll need PureBASIC v5.42.

Should compile under Linux and Mac, but didn’t have a chance to test (and I don’t own a Mac), so feedback is most welcome for other OSs’.

Project file is included, but will need some tweaking for building under Windows 32, and it might be no good for Linux and Mac due difference in path formatting. Unfortunately PureBASIC’s project files are not version control friendly.

Just compile `ntc.pb` in Console + ASCII mode and you’re good to go.

Future Plans And Contributing
-----------------------------

This first release was a bit of a rush thing, so I’ve left out of it quite a few ideas I wanted to add. But in the future I’m planning to expand ntc’s functionality, and also build a GUI version, and some tools to manage color names lists.

You are welcome to contribute to the project via issue requests, or by forking it and pull requesting.

How This Project Came About
---------------------------

This project was inspired by Chirag Mehta’s “[ntc js](http://chir.ag/projects/ntc/)” (Name that Color JavaScript), 2007 (CC BY 2.5). Ntc js is both a downloadable script to incorporate in one’s project, and an [online tool](http://chir.ag/projects/name-that-color/) accessible through a neat graphical interface. I’ve been resorting to it for ages, as a quick way to find appropriate names for colors in my CSS stylesheets, my color palettes, etc. So much so that I finally decided to search for a similar command line or GUI tool. To my surprise, there were no such tools — the only one I’ve found was ryanzec’s [Name That Color](https://github.com/ryanzec/name-that-color), a Node js CLI tool build around ntc js.

So I started looking into the code of ntc js and ryanzec’s Node version of it, which lead me to look into the issue of color difference/similarity algorithms — at its core, ntc js takes an input color values and runs it against a list of color name/values pairs, looking for an exact match and, failing that, comparing the input (target) color against all color values in the list, returning the closest match it found.

I couldn’t figure out which algorithm ntc js uses — it seems to measures the euclidean distance between the two colors in both RGB and HSL format, and then calculates a mean of the two with a slant toward HSL — and attempts to contact Chirag Mehta via email failed. But I realized it wasn’t using dE00, which is considered today the most reliable formula for the task.

So, I decided to take on the task of recreating Name That Color using Mehta’s color names list and the dE00 algorithm. Which lead us directly to the due credits…

Credits
-------

I expresses gratitude and attribute due credits to all those people whose work has rendered this project possible by sharing their source codes or by providing crucial information.

### Source Code Reuse

-   “ntc js” (Name that Color JavaScript) by Chirag Mehta, 2007 (CC BY 2.5) — This is the project that inspired the creation of ntc. It’s both an online tool and a JS script. The color names list used here is taken from ntc js, unaltered; but a different algorithm was used for comparing color similarity, yelding more accurate matches. Only the list of color names and values pairs was taken from this project, which Chirag Mehta compiled from different sources (see below).
    NOTE: ntc js’s algorithm, and design are copyrighted to Chirag Mehta, 2007.

    -   <http://chir.ag/projects/ntc/>

    -   <http://creativecommons.org/licenses/by/2.5/>

-   “php-color-difference” by [renasboy](https://github.com/renasboy) (no license claims) – ntc’s dE00 algorithm is a port of this PHP class.

    -   <https://github.com/renasboy/php-color-difference>
-   “dE00.js” by [Zachary Schuessler](https://github.com/zschuessler) (public domain) – This dE00 JavaScript implementation was heavily referenced while porting “php-color-difference” to PureBASIC; its comments eased understanding of the alogrithm, and its variables names were adopted instead of @renasboy’s.

    -   <https://github.com/zschuessler/DeltaE>
-   “RGB-LAB” (JavaScript) by [Kevin Kwok](https://github.com/antimatter15) (no license claims) – ntc’s RGB2Lab() procedure was built on an adaptation of its rgb2lab() function.

    -   <https://github.com/antimatter15/rgb-lab>

### Colors Names

Regarding the colors in this list, Chirag Mehta mentions in his credits the following sources:

-   “The Resene RGB Values List”, copyrighted to Resene Paints Ltd, 2001:

    -   <http://people.csail.mit.edu/jaffer/Color/resenecolours.txt>
-   Wikipedia’s entries for “Lists of colors” and “List of Crayola crayon olors”:

    -   <https://en.wikipedia.org/wiki/Lists_of_colors>

    -   <https://en.wikipedia.org/wiki/List_of_Crayola_crayon_colors>

-   Color-Name Dictionaries:

    -   <http://www-swiss.ai.mit.edu/~jaffer/Color/Dictionaries.html>

        \[ above link now redirects to: \]

    -   <http://people.csail.mit.edu/jaffer/Color/Dictionaries.html>

### Useful Resources

-   delta E Calculators – These online tools have been invaluable for testing accuracy of results during development:

    -   <http://www.boscarol.com/DeltaE.html>

    -   <http://colormine.org/delta-e-calculator/cie2000>

-   For insights into the code workings, I’ve been relying on Zachary Schuessler’s well commented “dE00.js” JavaScript implementation, and his informative website dedicated to Delta E Color Difference Algorithms:

    -   <https://github.com/zschuessler/DeltaE>

    -   <http://zschuessler.github.io/DeltaE/learn/>

-   EasyRGB – This website is a gold mine when it comes to digital colors math and formulas, providing lots of valuable pseudocode examples:

    -   <http://www.easyrgb.com/index.php?X=MATH>

