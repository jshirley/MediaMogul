# MediaMogul

Node based application, using Express and node-canvas with S3 file storage. Persistent storage and authentication stored in SQLite3.

## The Problem

I really hate the way that media is embedded on sites. It's cumbersome, and you generally have to either regenerate a site completely through obscure templates or edit each entry.

MediaMogul aims to manage the way your media is displayed and used on your site.

It does this through an API that delivers ready-to-embed markup for each asset, with classifications of assets able to specify separate default templates and profiles.

In a nutshell, on your blog you can say, "Show me the best `pie-fight` image for my blog". Which, as an API request, looks like a simple GET request to `http://media.shirley.im/embed/pie-fight/blog`.

What if you want to rotate the image? Easy! `http://media.shirley.im/embed/pie-fight/blog?rotate=90`.

But wait, there's more! Need to fit it in a 250px segment? `http://media.shirley.im/embed/pie-fight/blog?rotate=90&fit=250`.

The URI construction is pretty simple. You specify `/embed/$key`. The optional third argument is the profile (which can determine asset-type-specific defaults, like image width or video auto-play).

If the last argument ends in a .js extension, the output is wrapped in JavaScript which writes to the document the embed code. This enables behaviors like: `<script src="http://media.shirley.im/embed/pie-fight/blog.js"></script>`. This is not an ideal way of loading images, though!

## Dependencies

### Via npm:

* knox
* canvas
* sqlite3
* express
* yui
* config
* cli
* everyauth

And, of course, an S3 account for starters.

## Media Storage

Media storage is simply S3. S3 is ubiquitous and cheap.

## Authentication

You can host multiple users on the same MediaMogul install. Fun for you alone or all your friends. Except Zach.

By default, only the first registered user can use MediaMogul. If you want to open it up, there are two other modes:

### Open Enrollment

Anybody can register. Anybody can upload. This is probably not what you want, but in a private intranet could be useful.

### Invite Only

Each user gets invited with an invitation key, allowing them to sign-up. MediaMogul does not email this key, that's your job. It will, however, give it to you in a nicely packaged text box.

## Templating

Flexible templates, but to start with just handlebars.

## Media vs Embed

You can fetch the direct media with profiles directly, or fetch just the code necessary to embed it on the page. The intention is to fetch the embed code, which returns markup for use.

## Direct Media Fetching

Fetch media and the wrapping embed code accordingly:

    GET /media/$key/$profile

Such as

    GET /media/happy-people/thumbnail

Would return:

    <div class="thumbnail">
      <img src="//my.mediamogul.com/media/happy-people/-/300x200.jpg">
    </div>

Optional meta-data can affect the rendering, such as creating with attribution and a caption:

    <div class="thumbnail">
      <img src="//my.mediamogul.com/media/happy-people/-/300x200.jpg">
      <div class="caption">{{caption}}</div>
      <cite>The Noun Project</cite>
    </div>

## Primitives

    Asset
     - key
     - type (image, video)

    Asset Properties
     - key
     - value
     - safe (for html)

    Template
     - key
     - template
     - engine (default to handlebars)

## Open Questions

### Should MediaMogul store the CSS profiles for assets?

I'm inclined to say no, and should conform to some sane defaults. Perhaps merely Bootstrap, but easy to update and change.


