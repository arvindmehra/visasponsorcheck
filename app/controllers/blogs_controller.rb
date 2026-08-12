class BlogsController < ApplicationController
  def index
    @category = params[:category]
    @query = params[:q]

    @blogs = Blog.published
                 .by_category(@category)
                 .search_by_query(@query)

    @categories = ["All Categories"] + Blog::CATEGORIES

    set_meta_tags(
      title: "UK Immigration Insights Blog | VisaSponsorCheck",
      description: "Stay informed on UK immigration with expert insights on visas, sponsor licences, compliance, and HR updates.",
      canonical: blogs_url
    )
  end

  def show
    @blog = Blog.published.find_by!(slug: params[:slug])
    @related_blogs = Blog.published.where.not(id: @blog.id).by_category(@blog.category).limit(3)

    set_meta_tags(
      title: "#{@blog.title} | VisaSponsorCheck",
      description: @blog.meta_description,
      canonical: blog_url(@blog.slug),
      og: {
        title: @blog.title,
        description: @blog.meta_description,
        type: "article",
        url: blog_url(@blog.slug),
        image: @blog.featured_image_url
      }
    )
  end
end
