module Enterprise::DeleteObjectJob
  private

  def heavy_associations
    super.merge(
      SlaPolicy => %i[applied_slas]
    ).freeze
  end
end
