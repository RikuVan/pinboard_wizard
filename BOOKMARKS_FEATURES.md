# Bookmarks Features Documentation

## Overview

The bookmarks page has been enhanced with a modern, resizable layout and powerful tag filtering capabilities. This document describes the new features and improvements.

## Features

### 1. Resizable Split Layout

The bookmarks page now features a two-pane layout:

- **Main Content Pane (Left)**: Displays the list of bookmarks
- **Tags Panel (Right)**: Shows all available tags for filtering

#### Resizable Functionality

- **Drag to Resize**: Click and drag the divider between panes to adjust their relative sizes
- **Minimum Widths**: Each pane has a minimum width to ensure usability:
  - Main content: 400px minimum
  - Tags panel: 250px minimum
- **Initial Ratio**: The layout starts with 75% of the width allocated to the main content and 25% to the tags panel
- **Visual Feedback**: The divider changes appearance when being dragged

### 2. Tag Filtering System

#### Tags Panel Features

- **All Tags Display**: Shows all unique tags from your bookmarks, sorted alphabetically
- **Tag Count**: Displays the total number of available tags in the header
- **Clickable Tags**: Click any tag to add it to your active filters
- **Selected State**: Active filter tags are highlighted with a different color and checkmark icon

#### Filtering Behavior

- **Multi-Tag Filtering**: Select multiple tags to filter bookmarks that contain ALL selected tags (AND operation)
- **Real-time Updates**: The bookmark list updates immediately when tags are selected/deselected
- **Search Integration**: Tag filtering works alongside text search - both filters are applied simultaneously

#### Filter Management

- **Clear All Button**: Quickly remove all selected tags using the clear button in the header
- **Active Filters Display**: A footer section shows all currently active filter tags
- **Individual Tag Removal**: Remove specific tags from the active filters by clicking the × on each tag chip
- **Filter Count**: Shows how many tags are currently selected

### 3. Enhanced State Management

The bookmarks functionality has been refactored to use the BLoC/Cubit pattern:

#### BookmarksState

- Centralized state management for all bookmark-related data
- Includes tag management state (available tags, selected tags)
- Computed properties for filtered bookmark display

#### BookmarksCubit

- Business logic separated from UI components
- Methods for tag management:
  - `toggleTag(String tag)`: Add/remove a tag from filters
  - `clearSelectedTags()`: Remove all tag filters
  - `addTag(String tag)`: Add a specific tag to filters
  - `removeTag(String tag)`: Remove a specific tag from filters

### 4. Footer Information

The footer bar now provides comprehensive information:

- **Base Count**: Shows the number of bookmarks loaded or found
- **Filter Results**: When tags are selected, shows the count after filtering
- **Total Count**: Displays total bookmarks when all bookmarks are loaded

Example footer text: `150 bookmarks loaded • 23 after filtering`

## Usage

### Basic Tag Filtering

1. Browse the tags panel on the right side of the screen
2. Click on any tag to add it to your active filters
3. The bookmark list will update to show only bookmarks containing that tag
4. Add more tags to further narrow down the results

### Managing Filters

- **Add Multiple Tags**: Click multiple tags to create an AND filter
- **Remove Individual Tags**: Click the × next to a tag in the "Active Filters" section
- **Clear All Filters**: Click the clear button (×) in the tags panel header

### Resizing Panes

1. Hover over the divider between the bookmark list and tags panel
2. The cursor will change to a resize cursor (⟷)
3. Click and drag left or right to adjust the pane sizes
4. Release to set the new layout

### Combined Search and Filtering

- Use the search bar to find bookmarks by text content
- Use tag filters to narrow results by specific tags
- Both filters work together for powerful bookmark discovery

## Technical Implementation

### Components

- **ResizableSplitView**: Custom widget providing the resizable layout
- **TagsPanel**: Dedicated widget for tag display and interaction
- **BookmarksCubit**: State management for business logic
- **BookmarksState**: Immutable state class with computed properties

### Performance Considerations

- Tags are extracted and cached when bookmarks are loaded
- Filtering is performed on the client side for instant results
- State updates are optimized to minimize unnecessary rebuilds

## CRUD Operations

### Adding Bookmarks

The bookmarks page now includes full CRUD (Create, Read, Update, Delete) functionality starting with bookmark creation:

#### Add Bookmark Button

- **Location**: Top toolbar, left side next to the search bar
- **Action**: Opens the Add Bookmark dialog
- **Icon**: Plus (+) icon with "Add" label

#### Add Bookmark Dialog Features

- **URL Field**: Required field with validation for proper URL format
- **Title Field**: Required field for the bookmark title
- **Description**: Optional multi-line description field
- **Tags**: Space-separated tags that integrate with the filtering system
- **Privacy Options**:
  - Private bookmark (unchecked = public, checked = private)
  - Mark as "to read" for later reading
  - Replace existing bookmark if URL already exists

#### Smart Features

- **Clipboard Detection**: Automatically populates URL field if clipboard contains a valid URL
- **Auto-title Generation**: Suggests title based on URL domain when URL is pasted
- **Tag Normalization**: Tags are automatically converted to lowercase for consistency
- **Real-time Validation**: Form validation with helpful error messages
- **Loading States**: Shows progress indicator during bookmark creation

#### User Experience

- **Form Validation**: Prevents submission with missing required fields
- **Error Handling**: Clear error messages for API failures or validation issues
- **Immediate Update**: Bookmark list refreshes automatically after successful addition
- **Cancel Option**: Easy cancellation without losing the current bookmark list

### Workflow

1. Click the "Add" button in the toolbar
2. Fill in the bookmark details (URL and title are required)
3. Optionally add description, tags, and set privacy options
4. Click "Add Bookmark" to save
5. The dialog closes and the bookmark list updates with the new entry

## Future Enhancements

Potential future improvements could include:

- **Edit existing bookmarks** (Update functionality)
- **Delete bookmarks** (Delete functionality)
- **Bulk operations** (select multiple bookmarks for batch actions)
- **Import/Export** bookmarks from/to various formats
- **Tag color coding** and visual enhancements
- **Tag usage statistics** and analytics
- **Custom tag groups/categories**
- **Export filtered bookmark lists**
- **Saved filter presets**
- **Tag-based search suggestions**
- **Bookmark validation** (check for broken links)
- **Duplicate detection** and management
