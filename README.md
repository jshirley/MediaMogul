MediaMogul
=================

MediaMogul does two things. It tries to do them very well and hopefully it succeeds.

Media Storage
-----------------------------

First, it stores your media. This can be images, text, whatever. Doesn't matter. I'll be adding in support for more things like video as well.  It stores your media in MongoDB.

Media Delivery
-----------------------------

Second, it allows you to use your media in a sane way. MediaMogul can spit out snippets of markup just like a YouTube embed tag for your media. The markup is easily customized and specific to the type of media. Images, videos all can have different profiles.

But wait, there's more!
-----------------------------

MediaMogul also has transformation and pre-delivery steps. Right now this is only on images, but it lets you scale and rotate your images. If you use this feature (which you should) it is best to put MediaMogul behind something like Varnish.

MediaMogul is not a caching system. Every call to scale or rotate an image will do that same thing. Varnish is a caching system. Limelight is, too. Plan accordingly.  This will be explained later and cleaned up a lot more.

Customizing the snippets
--------------------------

You can create different markup snippets by simply creating a new template in the "templates" directory and passing in a param "profile". It is specific to the media type.

Drop a template in templates/image called "example.tt" and put something like this in:

    <div class="example">
        [% media_uri %] - This is the URI for accessing this media.
        [% asset.name %] - This is the object for the asset. ".name" returns name.
        [% asset.caption %] - And this returns the caption
    </div>

Then, just call /media/$image-name/embed?profile=example

Voila! Now you have a customized snippet returned.

The default profiles for images are "blog" and "thumbnail".  Blog will scale the images to a maximum edge of 500 pixels, and thumbnail is 250. 


Installation
------------------

Installation is currently a bit underdocumented. This is what works for me.

Use Debian Squeeze.

    sudo apt-get install mongodb git-core build-essential curl

Create a user (or your own user account) to run MediaMogul. Once you are logged in as that user, use perlbrew and cpanm (cpanminus) to install all the perl dependencies. I have a bootstrap script that works (but is only tested on Squeeze).

I recommend using Server::Starter and Plack (Starman). If you are going to use those, under the same account you are going to run MediaMogul as, run:

    cpanm Starman Server::Starter Catalyst::Engine::PSGI Net::Server::SS::PreFork

This will get you a preforking server that you can throw Varnish in front of. Then it is quite easy to run the application:

    cd MediaMogul
    start_server --port 127.0.0.1:8080 -- starman --workers 8 script/mediamogul.psgi

Now the app is running on port 8080. Go nuts!