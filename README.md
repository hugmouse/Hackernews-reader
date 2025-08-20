<div>
  <img 
    src="Hackernews Reader/Assets.xcassets/AppIcon.appiconset/HN-macOS-Default-128x128@1x.png" 
    alt="Hackernews Reader Icon">
  <h1 style="display: inline">
    Hacker News Reader for macOS
  </h1>
</div>

Native macOS reader for HackerNews. Based on official [Firebase API](https://github.com/HackerNews/API).

## Features

- Live updates – see changes to stories and comments in real-time `[1]`
- Search – fully local text search
- Tabs – just like in your favorite browser
- Offline support – read stories and comments offline

`[1]` You can disable live updates by clicking on "Live" button in the app's title.

## Screenshots

<table>
  <tr>
    <td>
      <picture>
        <source srcset="https://github.com/user-attachments/assets/650b18d2-e35a-4244-8d4e-51bce34ed344" media="(prefers-color-scheme: dark)" />
        <source srcset="https://github.com/user-attachments/assets/51e8bab7-e444-44d6-b5bf-625316ec1971" media="(prefers-color-scheme: light)" />
        <img alt="Screenshot of a main page of an app" src="https://github.com/user-attachments/assets/51e8bab7-e444-44d6-b5bf-625316ec1971"/>
      </picture>
    </td>
    <td>
      <picture>
        <source srcset="https://github.com/user-attachments/assets/93709032-4c17-408f-a0c1-3d62e0c6875d" media="(prefers-color-scheme: dark)" />
        <source srcset="https://github.com/user-attachments/assets/63339865-d8d7-4bd0-a465-d9763c2adf1f" media="(prefers-color-scheme: light)" />
        <img alt="Screenshot of a search page in an app" src="https://github.com/user-attachments/assets/63339865-d8d7-4bd0-a465-d9763c2adf1f" />
      </picture>
    </td>
  </tr>
  <tr>
    <td>Main view</td>
    <td>Search view</td>
  </tr>
</table>

## The Idea

One day, I found out that there was an official API for Hacker News. I decided to try implementing an application around it, which is how this reader came into existence.

The API itself is pretty limiting since it has no auth support. This means you can't comment, post news or really do anything besides reading.

Additionally, the way this API works requires the client to do a lot of requests, see more in [disadvantages](#disadvantages).

## Disadvantages

Using the Hacker News API means that the app has to make a lot of requests.
- First, we need to retrieve the IDs of the stories. 
- - Then, for each story, we need to make another request to retrieve information about the story.
- - - Finally, for a selected story, we need to load the comments and replies in a similar way.

For example we have a story with 2000 comments – which is the norm for "Best" stories – this generates over 2000 requests.
One request is made to get the stories, one to get a story, and over 2000 to get the comments and replies.

Thanks to this feature, browsing HN on a Nokia Lumia 630 is ultimately faster and uses less bandwidth.
This is thanks to server-side rendering, which means that you only need to make a few requests for icons, CSS and HTML.
