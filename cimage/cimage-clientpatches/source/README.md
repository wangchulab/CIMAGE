### Requirements

The following are pre-requisites of this module and its submodules

* [`node`](http://nodejs.org)
* [`npm`](http://npmjs.org)

`cimage-preview` requires Python 2.7.7+ (as well as pip and virtualenv) if you want to add this script to older files. For newer files it is recommended to modify `cimage_combine` rather than running this script every time.

`cimage-annotate` requires:

* python 2.7.7+
* mongodb
* web server capable of serving up python via cgi

Install process for this is not very straightforward at this moment so please talk to Radu for help. If you don't need this feature, you may comment out the appropriate line in `public/js/main.js`. Make sure to not only remove the path to `cimage-annotate` in the dependency array (`['cimage-preview/js/preview','cimage-annotate/js/annotate','cimage-utils/js/utils']`), but also the corresponding variable in the following function definition.


### Installing and building clientside files

```shell
npm install
bower install
gulp

```

`gulp` will generate a `dist` folder which you can take and upload to a publicly accessible location which will be pointed for inclusion on this suite of enhancement scripts in `combined_dta.html` files.
