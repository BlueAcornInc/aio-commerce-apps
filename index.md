---
title: Home
layout: home
nav_exclude: true
---

{%- comment -%}
  Cards are generated from the apps themselves: an app landing page is any page
  under /apps/ with no parent. Descriptions come from the opening lines of each
  app's own README, so this page cannot drift from the repos it documents --
  adding an app to the manifest is enough to make it appear here.

  Assigns live above the content, not inline: with whitespace control they
  otherwise collapse onto the following line, and kramdown then treats the
  opening <div> as inline text and prints it verbatim.
{%- endcomment -%}
{%- assign app_roots = site.html_pages
      | where_exp: 'p', "p.url contains '/apps/'"
      | where_exp: 'p', 'p.parent == nil'
      | where_exp: 'p', 'p.title'
      | sort: 'title' -%}

# Commerce Apps

Documentation and support for the Adobe Commerce apps built by Blue Acorn iCi.
Pick an app to see its installation guide, configuration reference and
storefront blocks.

<div class="app-grid">
{% for app in app_roots %}
  {%- comment -%}
    markdownify first: page.content is raw markdown here, so splitting on
    </h1> only works once it has been rendered. Closing tags become spaces so
    stripping them does not run the last word of one block into the next.
  {%- endcomment -%}
  {%- assign rendered = app.content | markdownify -%}
  {%- assign body = rendered | split: '</h1>' | last -%}
  {%- assign spaced = body | replace: '</p>', ' ' | replace: '</li>', ' ' | replace: '</h2>', ' ' -%}
  {%- assign desc = spaced | strip_html | strip_newlines | truncatewords: 24 -%}
  {%- assign app_parts = app.url | remove_first: '/' | split: '/' -%}
  {%- assign app_prefix = '/apps/' | append: app_parts[1] | append: '/' -%}
  {%- assign app_children = site.html_pages
        | where_exp: 'p', 'p.url contains app_prefix'
        | where_exp: 'p', 'p.parent == app.title'
        | where_exp: 'p', 'p.grand_parent == nil'
        | sort: 'nav_order' -%}
  <div class="app-card">
    <a class="app-card__title" href="{{ app.url | relative_url }}">{{ app.title }}</a>
    <span class="app-card__desc">{{ desc }}</span>
    {%- if app_children.size > 0 -%}
    <span class="app-card__links">
      <a href="{{ app.url | relative_url }}">Overview</a>
      {%- for child in app_children -%}
        <a href="{{ child.url | relative_url }}">{{ child.title }}</a>
      {%- endfor -%}
    </span>
    {%- endif -%}
  </div>
{% endfor %}
</div>

## Getting help

Each app links its issue tracker and contact address from the **Support** tab
inside the app itself. For anything else,
[open an issue](https://github.com/BlueAcornInc/aio-commerce-apps/issues).
